package dev.kof.compiler;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;

/**
 * Strict Kof IR to C11 lowering for the bounded Windows PE/COFF target.
 *
 * <p>The class deliberately lives in the compiler package. Kof 0.5.0-beta does
 * not expose a public optimized-IR frontend API, so this tool is pinned to the
 * exact Kof source revision enforced by the launcher. Unsupported IR is a
 * PE001 build error; it is never replaced with a stub.
 */
public final class KofPeBackendMain {
    private static final int MAX_METHODS = 8_192;
    private static final int MAX_OPERATIONS = 1_000_000;
    private static final int MAX_LOCALS = 1_024;
    private static final int MAX_STACK = 2_048;

    private KofPeBackendMain() {}

    public static void main(String[] args) {
        if (args.length < 2 || args.length > 3
                || (args.length == 3 && !args[2].equals("--library"))) {
            System.err.println("Usage: KofPeBackendMain <source.kf|directory> <generated.c> [--library]");
            System.exit(2);
        }
        try {
            Path source = Path.of(args[0]).toAbsolutePath().normalize();
            Path output = Path.of(args[1]).toAbsolutePath().normalize();
            boolean library = args.length == 3;
            List<Path> sources = collectSources(source);
            IRModule module = lower(sources);
            String generated = new CEmitter(module, library).emit();
            Path parent = output.getParent();
            if (parent != null) Files.createDirectories(parent);
            Files.writeString(output, generated, StandardCharsets.UTF_8);
            System.out.println("kof-pe-ir methods=" + methodCount(module)
                    + " source-files=" + sources.size());
        } catch (PeFailure failure) {
            System.err.println("PE001: " + failure.getMessage());
            System.exit(1);
        } catch (IOException failure) {
            System.err.println("PE001: I/O failure: " + failure.getMessage());
            System.exit(1);
        } catch (RuntimeException failure) {
            System.err.println("PE001: backend failure: " + failure.getMessage());
            System.exit(1);
        }
    }

    private static List<Path> collectSources(Path source) throws IOException {
        if (Files.isRegularFile(source) && source.getFileName().toString().endsWith(".kf")) {
            return List.of(source);
        }
        if (!Files.isDirectory(source)) {
            throw new PeFailure("source must be a .kf file or directory: " + source);
        }
        try (var paths = Files.walk(source)) {
            List<Path> sources = paths
                    .filter(Files::isRegularFile)
                    .filter(path -> path.getFileName().toString().endsWith(".kf"))
                    .sorted(Comparator.comparing(Path::toString))
                    .toList();
            if (sources.isEmpty()) throw new PeFailure("source directory contains no .kf files");
            return sources;
        }
    }

    private static IRModule lower(List<Path> sources) throws IOException {
        CompilerDriver driver = new CompilerDriver();
        DiagnosticCollector diagnostics = new DiagnosticCollector();
        Path moduleRoot = CompilerPipeline.rootFor(sources);
        driver.moduleRoot = moduleRoot;
        driver.target = Target.NATIVE;
        driver.currentDiagnostics = diagnostics;
        CompilerPipeline.flushClasspathWarnings(driver);
        driver.resetForCompilation();
        Path root = moduleRoot != null ? moduleRoot.toAbsolutePath().normalize() : null;
        CompilationUnitNode unit = CompilerPipeline.parseAndMerge(driver, sources, root, diagnostics);
        if (unit == null || diagnostics.hasErrors()) {
            throw new PeFailure(formatDiagnostics(diagnostics));
        }
        IRModule module = CompilerPipeline.analyzeAndLower(driver, unit, diagnostics);
        if (module == null || diagnostics.hasErrors()) {
            throw new PeFailure(formatDiagnostics(diagnostics));
        }
        for (Diagnostic diagnostic : diagnostics.getDiagnostics()) {
            if (diagnostic.severity() == Diagnostic.Severity.WARNING) {
                System.err.println(diagnostic.format());
            }
        }
        return module;
    }

    private static String formatDiagnostics(DiagnosticCollector diagnostics) {
        String text = diagnostics.formatAll().strip();
        return text.isEmpty() ? "Kof frontend rejected the source" : text;
    }

    private static int methodCount(IRModule module) {
        return module.classes().stream().mapToInt(value -> value.methods().size()).sum();
    }

    private static final class CEmitter {
        private final IRModule module;
        private final boolean library;
        private final List<MethodPlan> methods = new ArrayList<>();
        private final Map<MethodKey, MethodPlan> methodsByKey = new LinkedHashMap<>();
        private final Map<String, ClassPlan> classesByName = new LinkedHashMap<>();
        private final Map<String, Integer> fieldIndexes = new HashMap<>();
        private final Map<String, Integer> strings = new LinkedHashMap<>();
        private final Map<String, KofCall> ffiCalls = new TreeMap<>();
        private MethodPlan main;

        CEmitter(IRModule module, boolean library) {
            this.module = module;
            this.library = library;
        }

        String emit() {
            planModule();
            StringBuilder out = new StringBuilder(32_768);
            emitPreamble(out);
            emitFfiDeclarations(out);
            emitStrings(out);
            for (MethodPlan method : methods) {
                out.append("static KofValue ").append(method.cName())
                        .append("(const KofValue *args);\n");
            }
            out.append('\n');
            for (MethodPlan method : methods) emitMethod(out, method);
            emitEntry(out);
            return out.toString();
        }

        private void planModule() {
            if (module.classes().isEmpty()) throw fail("module contains no classes");
            Map<MethodKey, IRMethod> available = new LinkedHashMap<>();
            for (IRClass owner : module.classes()) {
                for (IRMethod method : owner.methods()) {
                    MethodKey key = new MethodKey(owner.name(), method.name(), method.parameterTypes());
                    if (available.put(key, method) != null) {
                        throw fail("duplicate method signature " + display(key));
                    }
                }
            }
            String expectedOwner = module.name().isEmpty() ? "Main" : module.name() + "/Main";
            MethodKey entryKey = available.keySet().stream()
                    .filter(key -> key.owner().equals(expectedOwner) && key.name().equals("main"))
                    .findFirst()
                    .orElseThrow(() -> fail("module has no main method"));
            LinkedHashSet<MethodKey> reachable = new LinkedHashSet<>();
            ArrayDeque<MethodKey> pending = new ArrayDeque<>();
            pending.add(entryKey);
            while (!pending.isEmpty()) {
                MethodKey key = pending.removeFirst();
                if (!reachable.add(key)) continue;
                IRMethod method = available.get(key);
                if (method == null) throw fail("missing reachable method " + display(key));
                for (KofOperation operation : flatten(method)) {
                    if (!(operation instanceof KofCall call)) continue;
                    if (isSupportedExternal(call)) {
                        if (isFfiCall(call)) registerFfi(call);
                        continue;
                    }
                    MethodKey target = callKey(call);
                    if (!available.containsKey(target)) {
                        throw fail(method.name() + " calls unavailable method " + display(target));
                    }
                    pending.add(target);
                }
            }
            if (reachable.size() > MAX_METHODS) {
                throw fail("reachable method count exceeds " + MAX_METHODS);
            }
            for (IRClass owner : module.classes()) {
                if (reachable.stream().noneMatch(key -> key.owner().equals(owner.name()))) continue;
                ClassPlan classPlan = new ClassPlan(owner.name(), owner.fields());
                classesByName.put(owner.name(), classPlan);
                for (int index = 0; index < owner.fields().size(); index++) {
                    IRField field = owner.fields().get(index);
                    String key = fieldKey(owner.name(), field.name(), field.type());
                    if (fieldIndexes.put(key, index) != null) {
                        throw fail("duplicate field " + key);
                    }
                }
            }
            List<MethodKey> ordered = new ArrayList<>(reachable);
            ordered.sort(Comparator.comparing(this::display));
            int ordinal = 0;
            for (MethodKey key : ordered) {
                IRMethod method = available.get(key);
                MethodPlan plan = new MethodPlan(key.owner(), method, "kof_method_" + ordinal++,
                        flatten(method), hasReceiver(method));
                methodsByKey.put(key, plan);
                methods.add(plan);
                if (key.equals(entryKey)) main = plan;
            }
            if (main == null) throw fail("module has no main method");
            validateMain(main.method());
            for (MethodPlan method : methods) {
                validateMethod(method);
                collectStrings(method.operations());
            }
        }

        private List<KofOperation> flatten(IRMethod method) {
            List<KofOperation> operations = new ArrayList<>();
            for (IRBasicBlock block : method.basicBlocks()) operations.addAll(block.operations());
            if (operations.size() > MAX_OPERATIONS) {
                throw fail(method.name() + " exceeds " + MAX_OPERATIONS + " IR operations");
            }
            return List.copyOf(operations);
        }

        private void validateMain(IRMethod method) {
            if (!Type.isVoid(method.returnType())) throw fail("main must return Void");
            if (method.parameterTypes().size() != 1
                    || !(method.parameterTypes().get(0) instanceof Type.ArrayType array)
                    || !Type.isString(array.componentType())) {
                throw fail("main must have the compiler-generated String[] parameter");
            }
        }

        private void validateMethod(MethodPlan plan) {
            IRMethod method = plan.method();
            if (!method.thrownExceptions().isEmpty()) {
                throw fail(method.name() + " declares exceptions, which the bounded target does not support");
            }
            if (!supportedValueType(method.returnType(), true)) {
                throw fail(method.name() + " has unsupported return type " + Type.display(method.returnType()));
            }
            boolean isMain = plan == main;
            for (int index = 0; index < method.parameterTypes().size(); index++) {
                Type type = method.parameterTypes().get(index);
                if (isMain && index == 0 && type instanceof Type.ArrayType) continue;
                if (!supportedValueType(type, false)) {
                    throw fail(method.name() + " has unsupported parameter type " + Type.display(type));
                }
            }
            int maxLocal = 0;
            for (IRLocalVariable local : method.localVariables()) {
                if (local.index() < 0 || local.index() >= MAX_LOCALS) {
                    throw fail(method.name() + " local index is outside 0.." + (MAX_LOCALS - 1));
                }
                if (!supportedValueType(local.type(), false)) {
                    throw fail(method.name() + " local " + local.name() + " has unsupported type "
                            + Type.display(local.type()));
                }
                maxLocal = Math.max(maxLocal, local.index() + 1);
            }
            plan.localCount(Math.max(1, maxLocal));
            validateOperations(plan);
            plan.maxStack(verifyControlFlow(plan));
        }

        private void validateOperations(MethodPlan plan) {
            List<KofOperation> operations = plan.operations();
            Set<Integer> labels = new HashSet<>();
            for (KofOperation operation : operations) {
                if (operation instanceof KofLabel label && !labels.add(label.label().id())) {
                    throw fail(plan.method().name() + " contains duplicate label " + label.label().id());
                }
            }
            for (int index = 0; index < operations.size(); index++) {
                KofOperation operation = operations.get(index);
                if (operation instanceof KofLoadLiteral literal) {
                    validateLiteral(plan, literal);
                } else if (operation instanceof KofLoadLocal local) {
                    validateLocal(plan, local.index(), local.type());
                } else if (operation instanceof KofStoreLocal local) {
                    validateLocal(plan, local.index(), local.type());
                } else if (operation instanceof KofNewObject object) {
                    if (!(object.type() instanceof Type.ClassType cls)
                            || !classesByName.containsKey(cls.internalName())) {
                        throw unsupported(plan, index, operation, "object class is not reachable");
                    }
                    for (Type type : object.argumentTypes()) {
                        if (!supportedValueType(type, false)) {
                            throw unsupported(plan, index, operation,
                                    "constructor argument type is unsupported");
                        }
                    }
                } else if (operation instanceof KofNewArray array) {
                    if (!supportedValueType(array.elementType(), false)) {
                        throw unsupported(plan, index, operation, "array element type is unsupported");
                    }
                } else if (operation instanceof KofArrayLoad array) {
                    if (!supportedValueType(array.elementType(), false)) {
                        throw unsupported(plan, index, operation, "array element type is unsupported");
                    }
                } else if (operation instanceof KofArrayStore array) {
                    if (!supportedValueType(array.elementType(), false)) {
                        throw unsupported(plan, index, operation, "array element type is unsupported");
                    }
                } else if (operation instanceof KofArrayLength) {
                    // Runtime checks the array tag and bounds.
                } else if (operation instanceof KofLoadField field) {
                    requireField(plan, index, field.ownerType(), field.name(), field.fieldType());
                } else if (operation instanceof KofStoreField field) {
                    requireField(plan, index, field.ownerType(), field.name(), field.fieldType());
                } else if (operation instanceof KofBinary binary) {
                    if (!supportedValueType(binary.operandType(), false)) {
                        throw unsupported(plan, index, operation, "binary operand type is unsupported");
                    }
                } else if (operation instanceof KofUnary unary) {
                    validateUnary(plan, index, unary);
                } else if (operation instanceof KofConditionalJump jump) {
                    if (!supportedValueType(jump.operandType(), false)) {
                        throw unsupported(plan, index, operation, "comparison operand type is unsupported");
                    }
                    requireLabel(plan, labels, jump.trueLabel().id());
                    requireLabel(plan, labels, jump.falseLabel().id());
                } else if (operation instanceof KofJump jump) {
                    requireLabel(plan, labels, jump.target().id());
                } else if (operation instanceof KofCall call) {
                    validateCall(plan, index, call, operations);
                } else if (operation instanceof KofGetStatic field) {
                    if (!isSystemOut(field)) {
                        throw unsupported(plan, index, operation, "only System.out is supported");
                    }
                } else if (operation instanceof KofReturn returned) {
                    if (!supportedValueType(returned.returnType(), false)) {
                        throw unsupported(plan, index, operation, "unsupported return type");
                    }
                } else if (operation instanceof KofThrow) {
                    // Uncaught Kof throws terminate the native process with a diagnostic.
                } else if (operation instanceof KofReturnVoid
                        || operation instanceof KofLabel
                        || operation instanceof KofContinueLabel
                        || operation instanceof KofStatementIf
                        || operation instanceof KofPop
                        || operation instanceof KofDup) {
                    // Supported structural or stack operation.
                } else {
                    throw unsupported(plan, index, operation, "operation is outside the PE target");
                }
            }
        }

        private void validateLiteral(MethodPlan plan, KofLoadLiteral literal) {
            if (literal.value() == null && supportedValueType(literal.type(), false)) return;
            if (Type.isString(literal.type()) && literal.value() instanceof String) return;
            if (isIntegral(literal.type()) && literal.value() instanceof Number) return;
            throw fail(plan.method().name() + " has unsupported literal type " + Type.display(literal.type()));
        }

        private void validateLocal(MethodPlan plan, int index, Type type) {
            if (index < 0 || index >= plan.localCount()) {
                throw fail(plan.method().name() + " references undeclared local " + index);
            }
            if (!supportedValueType(type, false)) {
                throw fail(plan.method().name() + " references unsupported local type " + Type.display(type));
            }
        }

        private void validateUnary(MethodPlan plan, int index, KofUnary unary) {
            if (!isIntegral(unary.operandType())) {
                throw unsupported(plan, index, unary, "floating-point unary operations are unsupported");
            }
            switch (unary.op()) {
                case NEG, NOT, I2L, I2C, I2B, I2S, L2I -> { }
                default -> throw unsupported(plan, index, unary, "conversion is outside the integral subset");
            }
        }

        private void validateCall(MethodPlan plan, int index, KofCall call,
                                  List<KofOperation> operations) {
            if (isFfiCall(call)) {
                validateFfiCall(plan, index, call);
                return;
            }
            if (isStringLength(call) || isStringCharAt(call)) return;
            if (isPrintCall(call)) return;
            if (isWrapperValueOf(call)) {
                if (index + 1 >= operations.size()
                        || !(operations.get(index + 1) instanceof KofCall next)
                        || !isStringValueOf(next)) {
                    throw unsupported(plan, index, call,
                            "primitive boxing is supported only in the compiler print pipeline");
                }
                return;
            }
            if (isStringValueOf(call)) {
                if (index + 1 >= operations.size()
                        || !(operations.get(index + 1) instanceof KofCall next)
                        || !isPrintCall(next)) {
                    throw unsupported(plan, index, call,
                            "String.valueOf is supported only immediately before print/println");
                }
                return;
            }
            MethodKey key = callKey(call);
            MethodPlan target = methodsByKey.get(key);
            if (target == null) {
                throw unsupported(plan, index, call, "call target is outside the reachable PE module");
            }
            boolean receiverCall = switch (call.kind()) {
                case INSTANCE, INTERFACE, SUPER, CONSTRUCTOR -> true;
                case FUNCTION, STATIC -> false;
            };
            if (receiverCall != target.hasReceiver()) {
                throw unsupported(plan, index, call, "call receiver convention does not match its target");
            }
            if (!target.method().returnType().equals(call.returnType())) {
                throw unsupported(plan, index, call, "call return type does not match its target");
            }
        }
        private void validateFfiCall(MethodPlan plan, int index, KofCall call) {
            try {
                validateFfiSignature(call);
                ffiSymbol(call);
            } catch (PeFailure failure) {
                throw unsupported(plan, index, call, failure.getMessage());
            }
        }

        private void requireField(MethodPlan plan, int index, Type owner, String name, Type type) {
            if (!fieldIndexes.containsKey(fieldKey(internalName(owner), name, type))) {
                throw unsupported(plan, index,
                        new KofLoadField(owner, name, type), "field is outside the reachable PE module");
            }
        }

        private int verifyControlFlow(MethodPlan plan) {
            List<KofOperation> operations = plan.operations();
            if (operations.isEmpty()) throw fail(plan.method().name() + " has no operations");
            Map<Integer, Integer> labelIndexes = new HashMap<>();
            for (int index = 0; index < operations.size(); index++) {
                KofOperation operation = operations.get(index);
                if (operation instanceof KofLabel label) {
                    labelIndexes.put(label.label().id(), index);
                } else if (operation instanceof KofContinueLabel label) {
                    labelIndexes.put(label.label().id(), index);
                }
            }
            Map<Integer, Integer> depths = new HashMap<>();
            ArrayDeque<Integer> pending = new ArrayDeque<>();
            depths.put(0, 0);
            pending.add(0);
            int maximum = 0;
            while (!pending.isEmpty()) {
                int index = pending.removeFirst();
                int before = depths.get(index);
                KofOperation operation = operations.get(index);
                int after = before + stackEffect(operation);
                int required = requiredDepth(operation);
                if (before < required || after < 0) {
                    throw fail(plan.method().name() + " has IR stack underflow at operation " + index);
                }
                if (after > MAX_STACK) {
                    throw fail(plan.method().name() + " exceeds the " + MAX_STACK + "-value stack limit");
                }
                maximum = Math.max(maximum, after);
                if (operation instanceof KofReturn || operation instanceof KofReturnVoid) {
                    if (after != 0) {
                        throw fail(plan.method().name() + " returns with " + after + " residual stack values");
                    }
                    continue;
                }
                if (operation instanceof KofJump jump) {
                    mergeDepth(plan, depths, pending, labelIndexes.get(jump.target().id()), after);
                    continue;
                }
                if (operation instanceof KofConditionalJump jump) {
                    mergeDepth(plan, depths, pending, labelIndexes.get(jump.trueLabel().id()), after);
                    mergeDepth(plan, depths, pending, labelIndexes.get(jump.falseLabel().id()), after);
                    continue;
                }
                if (index + 1 >= operations.size()) {
                    throw fail(plan.method().name() + " falls through without return");
                }
                mergeDepth(plan, depths, pending, index + 1, after);
            }
            return Math.max(1, maximum);
        }

        private void mergeDepth(MethodPlan plan, Map<Integer, Integer> depths,
                                ArrayDeque<Integer> pending, Integer index, int depth) {
            if (index == null) throw fail(plan.method().name() + " jumps to a missing label");
            Integer previous = depths.putIfAbsent(index, depth);
            if (previous == null) pending.add(index);
            else if (previous != depth) {
                throw fail(plan.method().name() + " has mismatched stack depth at operation " + index);
            }
        }

        private int stackEffect(KofOperation operation) {
            if (operation instanceof KofLoadLiteral || operation instanceof KofLoadLocal
                    || operation instanceof KofGetStatic || operation instanceof KofNewObject
                    || operation instanceof KofDup) return 1;
            if (operation instanceof KofStoreLocal || operation instanceof KofPop
                    || operation instanceof KofReturn || operation instanceof KofThrow) return -1;
            if (operation instanceof KofNewArray || operation instanceof KofArrayLength
                    || operation instanceof KofLoadField) return 0;
            if (operation instanceof KofArrayLoad || operation instanceof KofBinary) return -1;
            if (operation instanceof KofArrayStore) return -3;
            if (operation instanceof KofStoreField) return -2;
            if (operation instanceof KofConditionalJump) return -2;
            if (operation instanceof KofCall call) {
                int consumed = call.parameterTypes().size();
                if (call.kind() == KofCallKind.INSTANCE || call.kind() == KofCallKind.INTERFACE
                        || call.kind() == KofCallKind.SUPER || call.kind() == KofCallKind.CONSTRUCTOR) {
                    consumed++;
                }
                return (Type.isVoid(call.returnType()) ? 0 : 1) - consumed;
            }
            return 0;
        }

        private int requiredDepth(KofOperation operation) {
            if (operation instanceof KofBinary || operation instanceof KofConditionalJump) return 2;
            if (operation instanceof KofStoreLocal || operation instanceof KofPop
                    || operation instanceof KofReturn || operation instanceof KofUnary
                    || operation instanceof KofDup || operation instanceof KofThrow
                    || operation instanceof KofArrayLength || operation instanceof KofLoadField) return 1;
            if (operation instanceof KofNewArray) return 1;
            if (operation instanceof KofArrayLoad) return 2;
            if (operation instanceof KofArrayStore) return 3;
            if (operation instanceof KofStoreField) return 2;
            if (operation instanceof KofCall call) {
                int required = call.parameterTypes().size();
                if (call.kind() == KofCallKind.INSTANCE || call.kind() == KofCallKind.INTERFACE
                        || call.kind() == KofCallKind.SUPER || call.kind() == KofCallKind.CONSTRUCTOR) {
                    required++;
                }
                return required;
            }
            return 0;
        }

        private void collectStrings(List<KofOperation> operations) {
            for (KofOperation operation : operations) {
                if (operation instanceof KofLoadLiteral literal && literal.value() instanceof String value) {
                    strings.computeIfAbsent(value, ignored -> strings.size());
                }
            }
        }

        private void emitPreamble(StringBuilder out) {
            out.append("""
                    /* Generated from Kof IR by the native Windows PE/COFF backend. */
                    #include <stdint.h>
                    #include <stdbool.h>
                    #include <stddef.h>
                    #include <stdio.h>
                    #include <stdlib.h>
                    #include <string.h>
                    #include <limits.h>

                    #if defined(__GNUC__)
                    #define KOF_UNUSED __attribute__((unused))
                    #else
                    #define KOF_UNUSED
                    #endif

                    typedef enum {
                        KOF_NIL = 0,
                        KOF_INT = 1,
                        KOF_BOOL = 2,
                        KOF_STRING = 3,
                        KOF_OBJECT = 4,
                        KOF_ARRAY = 5,
                        KOF_OUT = 6
                    } KofTag;

                    typedef struct KofValue KofValue;
                    typedef struct KofString KofString;
                    typedef struct KofObject KofObject;
                    typedef struct KofArray KofArray;

                    struct KofValue {
                        KofTag tag;
                        uint64_t bits;
                        void *ref;
                    };

                    struct KofString {
                        const unsigned char *bytes;
                        size_t length;
                    };

                    struct KofObject {
                        const char *class_name;
                        size_t field_count;
                        KofValue *fields;
                    };

                    struct KofArray {
                        KofTag element_tag;
                        size_t length;
                        KofValue *values;
                    };

                    static KOF_UNUSED void kof_fail(const char *message) {
                        fputs("kof-pe runtime: ", stderr);
                        fputs(message, stderr);
                        fputc(10, stderr);
                        exit(70);
                    }

                    static KOF_UNUSED KofValue kof_nil(void) {
                        return (KofValue){KOF_NIL, 0, NULL};
                    }

                    static KOF_UNUSED KofValue kof_int(int64_t value) {
                        return (KofValue){KOF_INT, (uint64_t)value, NULL};
                    }

                    static KOF_UNUSED KofValue kof_bool(int value) {
                        return (KofValue){KOF_BOOL, value ? 1u : 0u, NULL};
                    }

                    static KOF_UNUSED KofValue kof_out(void) {
                        return (KofValue){KOF_OUT, 0, NULL};
                    }

                    static KOF_UNUSED KofValue kof_default(KofTag tag) {
                        return tag == KOF_BOOL ? kof_bool(0) :
                               tag == KOF_INT ? kof_int(0) : kof_nil();
                    }

                    static KOF_UNUSED void kof_push(
                            KofValue *stack, size_t *sp, size_t limit, KofValue value) {
                        if (*sp >= limit) kof_fail("value stack overflow");
                        stack[(*sp)++] = value;
                    }

                    static KOF_UNUSED KofValue kof_pop(KofValue *stack, size_t *sp) {
                        if (*sp == 0) kof_fail("value stack underflow");
                        return stack[--(*sp)];
                    }

                    static KOF_UNUSED int64_t kof_integral(KofValue value) {
                        if (value.tag != KOF_INT && value.tag != KOF_BOOL) {
                            kof_fail("expected integral value");
                        }
                        return (int64_t)value.bits;
                    }

                    static KOF_UNUSED int32_t kof_i32(int64_t value) {
                        return (int32_t)(uint32_t)value;
                    }

                    static KOF_UNUSED int64_t kof_add32(int64_t a, int64_t b) {
                        return kof_i32((uint32_t)a + (uint32_t)b);
                    }

                    static KOF_UNUSED int64_t kof_sub32(int64_t a, int64_t b) {
                        return kof_i32((uint32_t)a - (uint32_t)b);
                    }

                    static KOF_UNUSED int64_t kof_mul32(int64_t a, int64_t b) {
                        return kof_i32((uint32_t)a * (uint32_t)b);
                    }

                    static KOF_UNUSED int64_t kof_div32(int64_t a, int64_t b) {
                        int32_t x = kof_i32(a);
                        int32_t y = kof_i32(b);
                        if (y == 0) kof_fail("division by zero");
                        if (x == INT32_MIN && y == -1) return INT32_MIN;
                        return x / y;
                    }

                    static KOF_UNUSED int64_t kof_mod32(int64_t a, int64_t b) {
                        int32_t x = kof_i32(a);
                        int32_t y = kof_i32(b);
                        if (y == 0) kof_fail("division by zero");
                        if (x == INT32_MIN && y == -1) return 0;
                        return x % y;
                    }

                    static KOF_UNUSED int64_t kof_div64(int64_t a, int64_t b) {
                        if (b == 0) kof_fail("division by zero");
                        if (a == INT64_MIN && b == -1) return INT64_MIN;
                        return a / b;
                    }

                    static KOF_UNUSED int64_t kof_mod64(int64_t a, int64_t b) {
                        if (b == 0) kof_fail("division by zero");
                        if (a == INT64_MIN && b == -1) return 0;
                        return a % b;
                    }

                    static KOF_UNUSED int64_t kof_shr32(int64_t a, int64_t b) {
                        uint32_t x = (uint32_t)a;
                        uint32_t n = (uint32_t)b & 31u;
                        if (n == 0) return kof_i32(x);
                        return kof_i32((x >> n) |
                            ((x & 0x80000000u) ? (~UINT32_C(0) << (32u - n)) : 0u));
                    }

                    static KOF_UNUSED int64_t kof_shr64(int64_t a, int64_t b) {
                        uint64_t x = (uint64_t)a;
                        uint64_t n = (uint64_t)b & 63u;
                        if (n == 0) return (int64_t)x;
                        return (int64_t)((x >> n) |
                            ((x & UINT64_C(0x8000000000000000)) ?
                                (~UINT64_C(0) << (64u - n)) : 0u));
                    }

                    static KOF_UNUSED KofString *kof_string_new(
                            const unsigned char *bytes, size_t length, int copy) {
                        KofString *string = (KofString *)malloc(sizeof(*string));
                        if (string == NULL) kof_fail("string allocation failed");
                        unsigned char *owned = NULL;
                        if (copy) {
                            owned = (unsigned char *)malloc(length == 0 ? 1 : length);
                            if (owned == NULL) kof_fail("string allocation failed");
                            if (length != 0) memcpy(owned, bytes, length);
                        }
                        string->bytes = copy ? owned : bytes;
                        string->length = length;
                        return string;
                    }

                    static KOF_UNUSED KofValue kof_string(
                            const unsigned char *bytes, size_t length) {
                        return (KofValue){KOF_STRING, 0, kof_string_new(bytes, length, 0)};
                    }

                    static KOF_UNUSED KofValue kof_string_value_of(KofValue value) {
                        if (value.tag == KOF_STRING) return value;
                        char buffer[64];
                        int length;
                        if (value.tag == KOF_BOOL) {
                            const char *text = value.bits ? "true" : "false";
                            KofString *string = kof_string_new(
                                (const unsigned char *)text, strlen(text), 1);
                            return (KofValue){KOF_STRING, 0, string};
                        }
                        if (value.tag == KOF_INT) {
                            length = snprintf(buffer, sizeof(buffer), "%lld",
                                (long long)(int64_t)value.bits);
                        } else if (value.tag == KOF_NIL) {
                            return (KofValue){KOF_STRING, 0,
                                kof_string_new((const unsigned char *)"null", 4, 1)};
                        } else {
                            return (KofValue){KOF_STRING, 0,
                                kof_string_new((const unsigned char *)"object", 6, 1)};
                        }
                        if (length < 0) kof_fail("string conversion failed");
                        return (KofValue){KOF_STRING, 0,
                            kof_string_new((const unsigned char *)buffer, (size_t)length, 1)};
                    }

                    static KOF_UNUSED int kof_string_equal(KofValue left, KofValue right) {
                        if (left.tag != KOF_STRING || right.tag != KOF_STRING) return 0;
                        KofString *a = (KofString *)left.ref;
                        KofString *b = (KofString *)right.ref;
                        return a->length == b->length &&
                            (a->length == 0 || memcmp(a->bytes, b->bytes, a->length) == 0);
                    }

                    static KOF_UNUSED KofValue kof_string_length(KofValue value) {
                        if (value.tag != KOF_STRING) kof_fail("expected string");
                        return kof_int((int64_t)((KofString *)value.ref)->length);
                    }

                    static KOF_UNUSED KofValue kof_string_char_at(
                            KofValue value, int64_t index) {
                        if (value.tag != KOF_STRING) kof_fail("expected string");
                        KofString *string = (KofString *)value.ref;
                        if (index < 0 || (uint64_t)index >= string->length) {
                            kof_fail("string index out of bounds");
                        }
                        return kof_int((unsigned char)string->bytes[index]);
                    }

                    static KOF_UNUSED KofValue kof_object_new(
                            const char *class_name, size_t field_count) {
                        KofObject *object = (KofObject *)calloc(1, sizeof(*object));
                        if (object == NULL) kof_fail("object allocation failed");
                        object->class_name = class_name;
                        object->field_count = field_count;
                        object->fields = (KofValue *)calloc(
                            field_count == 0 ? 1 : field_count, sizeof(*object->fields));
                        if (object->fields == NULL) kof_fail("field allocation failed");
                        return (KofValue){KOF_OBJECT, 0, object};
                    }

                    static KOF_UNUSED KofValue kof_object_load(
                            KofValue value, size_t index) {
                        if (value.tag != KOF_OBJECT) kof_fail("expected object receiver");
                        KofObject *object = (KofObject *)value.ref;
                        if (index >= object->field_count) kof_fail("field index out of bounds");
                        return object->fields[index];
                    }

                    static KOF_UNUSED void kof_object_store(
                            KofValue value, size_t index, KofValue field) {
                        if (value.tag != KOF_OBJECT) kof_fail("expected object receiver");
                        KofObject *object = (KofObject *)value.ref;
                        if (index >= object->field_count) kof_fail("field index out of bounds");
                        object->fields[index] = field;
                    }

                    static KOF_UNUSED KofValue kof_array_new(
                            size_t length, KofTag element_tag) {
                        KofArray *array = (KofArray *)calloc(1, sizeof(*array));
                        if (array == NULL) kof_fail("array allocation failed");
                        array->element_tag = element_tag;
                        array->length = length;
                        array->values = (KofValue *)calloc(
                            length == 0 ? 1 : length, sizeof(*array->values));
                        if (array->values == NULL) kof_fail("array allocation failed");
                        for (size_t index = 0; index < length; ++index) {
                            array->values[index] = kof_default(element_tag);
                        }
                        return (KofValue){KOF_ARRAY, 0, array};
                    }

                    static KOF_UNUSED KofValue kof_array_load(
                            KofValue value, int64_t index) {
                        if (value.tag != KOF_ARRAY) kof_fail("expected array");
                        KofArray *array = (KofArray *)value.ref;
                        if (index < 0 || (uint64_t)index >= array->length) {
                            kof_fail("array index out of bounds");
                        }
                        return array->values[index];
                    }

                    static KOF_UNUSED void kof_array_store(
                            KofValue value, int64_t index, KofValue element) {
                        if (value.tag != KOF_ARRAY) kof_fail("expected array");
                        KofArray *array = (KofArray *)value.ref;
                        if (index < 0 || (uint64_t)index >= array->length) {
                            kof_fail("array index out of bounds");
                        }
                        array->values[index] = element;
                    }

                    static KOF_UNUSED size_t kof_array_length(KofValue value) {
                        if (value.tag != KOF_ARRAY) kof_fail("expected array");
                        return ((KofArray *)value.ref)->length;
                    }

                    static KOF_UNUSED void kof_print(
                            KofValue out, KofValue value, int newline) {
                        if (out.tag != KOF_OUT) kof_fail("invalid print receiver");
                        if (value.tag == KOF_STRING) {
                            KofString *string = (KofString *)value.ref;
                            if (string->length != 0 &&
                                fwrite(string->bytes, 1, string->length, stdout) != string->length) {
                                kof_fail("stdout write failed");
                            }
                        } else if (value.tag == KOF_BOOL) {
                            if (fputs(value.bits ? "true" : "false", stdout) < 0) {
                                kof_fail("stdout write failed");
                            }
                        } else if (value.tag == KOF_INT) {
                            if (fprintf(stdout, "%lld", (long long)(int64_t)value.bits) < 0) {
                                kof_fail("stdout write failed");
                            }
                        } else if (value.tag == KOF_NIL) {
                            if (fputs("null", stdout) < 0) kof_fail("stdout write failed");
                        } else if (value.tag == KOF_OBJECT) {
                            if (fputs("<object>", stdout) < 0) kof_fail("stdout write failed");
                        } else if (value.tag == KOF_ARRAY) {
                            if (fputs("<array>", stdout) < 0) kof_fail("stdout write failed");
                        } else {
                            kof_fail("unsupported printable value");
                        }
                        if (newline && fputc(10, stdout) == EOF) {
                            kof_fail("stdout write failed");
                        }
                    }
                    """);
        }

        private void emitFfiDeclarations(StringBuilder out) {
            for (KofCall call : ffiCalls.values()) {
                out.append("extern ").append(cAbiType(call.returnType())).append(' ')
                        .append(ffiSymbol(call)).append('(');
                if (call.parameterTypes().isEmpty()) {
                    out.append("void");
                } else {
                    for (int index = 0; index < call.parameterTypes().size(); index++) {
                        if (index != 0) out.append(", ");
                        out.append(cAbiType(call.parameterTypes().get(index)));
                    }
                }
                out.append(");\n");
            }
            if (!ffiCalls.isEmpty()) out.append('\n');
        }

        private String cAbiType(Type type) {
            if (Type.isVoid(type)) return "void";
            if (isBool(type)) return "bool";
            return isLong(type) ? "int64_t" : "int32_t";
        }

        private void emitStrings(StringBuilder out) {
            for (Map.Entry<String, Integer> entry : strings.entrySet()) {
                byte[] bytes = entry.getKey().getBytes(StandardCharsets.UTF_8);
                out.append("static const unsigned char kof_string_").append(entry.getValue()).append("[] = {");
                if (bytes.length == 0) out.append('0');
                for (int index = 0; index < bytes.length; index++) {
                    if (index != 0) out.append(',');
                    out.append(Byte.toUnsignedInt(bytes[index]));
                }
                out.append("};\n");
            }
            if (!strings.isEmpty()) out.append('\n');
        }

        private void emitMethod(StringBuilder out, MethodPlan plan) {
            IRMethod method = plan.method();
            out.append("static KOF_UNUSED KofValue ").append(plan.cName())
                    .append("(const KofValue *args) {\n")
                    .append("    KofValue stack[").append(plan.maxStack()).append("];\n")
                    .append("    KofValue locals[").append(plan.localCount()).append("];\n")
                    .append("    size_t sp = 0;\n")
                    .append("    for (size_t i = 0; i < ").append(plan.localCount())
                    .append("; ++i) locals[i] = kof_nil();\n")
                    .append("    (void)locals;\n")
                    .append("    (void)args;\n");
            int offset = plan.hasReceiver() ? 1 : 0;
            if (plan.hasReceiver()) {
                out.append("    locals[0] = args[0];\n");
            }
            for (int index = 0; index < method.parameterTypes().size(); index++) {
                out.append("    locals[").append(index + offset).append("] = args[")
                        .append(index + offset).append("];\n");
            }
            List<KofOperation> operations = plan.operations();
            Set<Integer> referencedLabels = referencedLabels(operations);
            Set<Integer> emittedLabels = new HashSet<>();
            for (int index = 0; index < operations.size(); index++) {
                emitOperation(out, plan, index, operations.get(index), referencedLabels, emittedLabels);
            }
            out.append("    return kof_nil();\n}\n\n");
        }

        private Set<Integer> referencedLabels(List<KofOperation> operations) {
            Set<Integer> labels = new LinkedHashSet<>();
            for (KofOperation operation : operations) {
                if (operation instanceof KofJump jump) labels.add(jump.target().id());
                if (operation instanceof KofConditionalJump jump) {
                    labels.add(jump.trueLabel().id());
                    labels.add(jump.falseLabel().id());
                }
            }
            return labels;
        }

        private void emitOperation(StringBuilder out, MethodPlan plan, int index,
                                   KofOperation operation, Set<Integer> referencedLabels,
                                   Set<Integer> emittedLabels) {
            String limit = Integer.toString(plan.maxStack());
            if (operation instanceof KofLoadLiteral literal) {
                if (literal.value() == null) {
                    out.append("    kof_push(stack, &sp, ").append(limit).append(", kof_nil());\n");
                } else if (literal.value() instanceof String value) {
                    int id = strings.get(value);
                    int length = value.getBytes(StandardCharsets.UTF_8).length;
                    out.append("    kof_push(stack, &sp, ").append(limit)
                            .append(", kof_string(kof_string_").append(id).append(", ")
                            .append(length).append("));\n");
                } else {
                    long value = ((Number) literal.value()).longValue();
                    if (isBool(literal.type())) {
                        out.append("    kof_push(stack, &sp, ").append(limit).append(", kof_bool(")
                                .append(value == 0 ? 0 : 1).append("));\n");
                    } else {
                        out.append("    kof_push(stack, &sp, ").append(limit)
                                .append(", kof_int(INT64_C(").append(value).append(")));\n");
                    }
                }
            } else if (operation instanceof KofLoadLocal local) {
                out.append("    kof_push(stack, &sp, ").append(limit).append(", locals[")
                        .append(local.index()).append("]);\n");
            } else if (operation instanceof KofStoreLocal local) {
                out.append("    locals[").append(local.index()).append("] = kof_pop(stack, &sp);\n");
            } else if (operation instanceof KofNewObject object) {
                String owner = internalName(object.type());
                ClassPlan classPlan = classesByName.get(owner);
                out.append("    { KofValue object_").append(index).append(" = kof_object_new(\"")
                        .append(owner).append("\", ").append(classPlan.fields().size()).append(");\n");
                for (int field = 0; field < classPlan.fields().size(); field++) {
                    out.append("      ((KofObject *)object_").append(index).append(".ref)->fields[")
                            .append(field).append("] = kof_default(")
                            .append(tagFor(classPlan.fields().get(field).type())).append(");\n");
                }
                out.append("      kof_push(stack, &sp, ").append(limit).append(", object_")
                        .append(index).append("); }\n");
            } else if (operation instanceof KofNewArray array) {
                out.append("    { KofValue length_").append(index)
                        .append(" = kof_pop(stack, &sp); kof_push(stack, &sp, ").append(limit)
                        .append(", kof_array_new((size_t)kof_integral(length_").append(index)
                        .append("), ").append(tagFor(array.elementType())).append(")); }\n");
            } else if (operation instanceof KofArrayLoad) {
                out.append("    { KofValue index_").append(index)
                        .append(" = kof_pop(stack, &sp); KofValue array_").append(index)
                        .append(" = kof_pop(stack, &sp); kof_push(stack, &sp, ").append(limit)
                        .append(", kof_array_load(array_").append(index).append(", kof_integral(index_")
                        .append(index).append("))); }\n");
            } else if (operation instanceof KofArrayStore) {
                out.append("    { KofValue value_").append(index)
                        .append(" = kof_pop(stack, &sp); KofValue index_").append(index)
                        .append(" = kof_pop(stack, &sp); KofValue array_").append(index)
                        .append(" = kof_pop(stack, &sp); kof_array_store(array_").append(index)
                        .append(", kof_integral(index_").append(index).append("), value_")
                        .append(index).append("); }\n");
            } else if (operation instanceof KofArrayLength) {
                out.append("    { KofValue array_").append(index)
                        .append(" = kof_pop(stack, &sp); kof_push(stack, &sp, ").append(limit)
                        .append(", kof_int((int64_t)kof_array_length(array_").append(index)
                        .append("))); }\n");
            } else if (operation instanceof KofLoadField field) {
                out.append("    { KofValue receiver_").append(index)
                        .append(" = kof_pop(stack, &sp); kof_push(stack, &sp, ").append(limit)
                        .append(", kof_object_load(receiver_").append(index).append(", ")
                        .append(fieldIndex(field.ownerType(), field.name(), field.fieldType())).append(")); }\n");
            } else if (operation instanceof KofStoreField field) {
                out.append("    { KofValue value_").append(index)
                        .append(" = kof_pop(stack, &sp); KofValue receiver_").append(index)
                        .append(" = kof_pop(stack, &sp); kof_object_store(receiver_").append(index)
                        .append(", ").append(fieldIndex(field.ownerType(), field.name(), field.fieldType()))
                        .append(", value_").append(index).append("); }\n");
            } else if (operation instanceof KofBinary binary) {
                emitBinary(out, binary, limit, index);
            } else if (operation instanceof KofUnary unary) {
                emitUnary(out, unary, limit, index);
            } else if (operation instanceof KofConditionalJump jump) {
                out.append("    { KofValue right_").append(index).append(" = kof_pop(stack, &sp); KofValue left_")
                        .append(index).append(" = kof_pop(stack, &sp); if (")
                        .append(comparisonExpression(jump.comparison(), jump.operandType(),
                                "left_" + index, "right_" + index))
                        .append(") goto kof_label_").append(jump.trueLabel().id())
                        .append("; else goto kof_label_").append(jump.falseLabel().id()).append("; }\n");
            } else if (operation instanceof KofJump jump) {
                out.append("    goto kof_label_").append(jump.target().id()).append(";\n");
            } else if (operation instanceof KofLabel label) {
                if (referencedLabels.contains(label.label().id()) && emittedLabels.add(label.label().id())) {
                    out.append("kof_label_").append(label.label().id()).append(":\n");
                }
            } else if (operation instanceof KofContinueLabel label) {
                if (referencedLabels.contains(label.label().id()) && emittedLabels.add(label.label().id())) {
                    out.append("kof_label_").append(label.label().id()).append(":\n");
                }
            } else if (operation instanceof KofCall call) {
                emitCall(out, call, limit, index);
            } else if (operation instanceof KofGetStatic) {
                out.append("    kof_push(stack, &sp, ").append(limit).append(", kof_out());\n");
            } else if (operation instanceof KofReturn) {
                out.append("    return kof_pop(stack, &sp);\n");
            } else if (operation instanceof KofReturnVoid) {
                out.append("    return kof_nil();\n");
            } else if (operation instanceof KofPop) {
                out.append("    (void)kof_pop(stack, &sp);\n");
            } else if (operation instanceof KofDup) {
                out.append("    { KofValue value_").append(index)
                        .append(" = kof_pop(stack, &sp); kof_push(stack, &sp, ").append(limit)
                        .append(", value_").append(index).append("); kof_push(stack, &sp, ")
                        .append(limit).append(", value_").append(index).append("); }\n");
            } else if (operation instanceof KofThrow) {
                out.append("    (void)kof_pop(stack, &sp); kof_fail(\"uncaught Kof throw\");\n");
            } else if (operation instanceof KofStatementIf) {
                out.append("    /* Kof statement-if marker */\n");
            } else {
                throw unsupported(plan, index, operation, "operation escaped validation");
            }
        }

        private void emitBinary(StringBuilder out, KofBinary binary, String limit, int index) {
            boolean wide = isLong(binary.operandType());
            out.append("    { int64_t right = kof_integral(kof_pop(stack, &sp)); int64_t left = kof_integral(kof_pop(stack, &sp));\n")
                    .append("      kof_push(stack, &sp, ").append(limit).append(", ");
            switch (binary.op()) {
                case ADD -> out.append("kof_int(").append(wide ? "(int64_t)((uint64_t)left + (uint64_t)right)" : "kof_add32(left, right)").append(')');
                case SUB -> out.append("kof_int(").append(wide ? "(int64_t)((uint64_t)left - (uint64_t)right)" : "kof_sub32(left, right)").append(')');
                case MUL -> out.append("kof_int(").append(wide ? "(int64_t)((uint64_t)left * (uint64_t)right)" : "kof_mul32(left, right)").append(')');
                case DIV -> out.append("kof_int(").append(wide ? "kof_div64(left, right)" : "kof_div32(left, right)").append(')');
                case MOD -> out.append("kof_int(").append(wide ? "kof_mod64(left, right)" : "kof_mod32(left, right)").append(')');
                case EQ, NE, LT, LE, GT, GE -> out.append("kof_bool(")
                        .append(comparisonExpression(toComparison(binary.op()), binary.operandType(),
                                "kof_int(left)", "kof_int(right)")).append(')');
                case AND -> out.append("kof_int(").append(wide ? "(int64_t)((uint64_t)left & (uint64_t)right)" : "kof_i32((uint32_t)left & (uint32_t)right)").append(')');
                case OR -> out.append("kof_int(").append(wide ? "(int64_t)((uint64_t)left | (uint64_t)right)" : "kof_i32((uint32_t)left | (uint32_t)right)").append(')');
                case XOR -> out.append("kof_int(").append(wide ? "(int64_t)((uint64_t)left ^ (uint64_t)right)" : "kof_i32((uint32_t)left ^ (uint32_t)right)").append(')');
                case SHL -> out.append("kof_int(").append(wide
                        ? "(int64_t)((uint64_t)left << ((uint64_t)right & 63u))"
                        : "kof_i32((uint32_t)left << ((uint32_t)right & 31u))").append(')');
                case SHR -> out.append("kof_int(").append(wide ? "kof_shr64(left, right)" : "kof_shr32(left, right)").append(')');
                case USHR -> out.append("kof_int(").append(wide
                        ? "(int64_t)((uint64_t)left >> ((uint64_t)right & 63u))"
                        : "kof_i32((uint32_t)left >> ((uint32_t)right & 31u))").append(')');
                default -> throw new PeFailure("unhandled binary operation at " + index);
            }
            out.append("); }\n");
        }

        private void emitUnary(StringBuilder out, KofUnary unary, String limit, int index) {
            out.append("    { int64_t value = kof_integral(kof_pop(stack, &sp)); kof_push(stack, &sp, ")
                    .append(limit).append(", ");
            switch (unary.op()) {
                case NEG -> out.append("kof_int(").append(isLong(unary.operandType())
                        ? "(int64_t)(UINT64_C(0) - (uint64_t)value)"
                        : "kof_i32(UINT32_C(0) - (uint32_t)value)").append(')');
                case NOT -> out.append("kof_bool(value == 0)");
                case I2L -> out.append("kof_int(kof_i32(value))");
                case I2C -> out.append("kof_int((int64_t)((uint32_t)value & UINT32_C(0xffff)))");
                case I2B -> out.append("kof_int((int64_t)(int8_t)(uint8_t)value)");
                case I2S -> out.append("kof_int((int64_t)(int16_t)(uint16_t)value)");
                case L2I -> out.append("kof_int(kof_i32(value))");
                default -> throw new PeFailure("unhandled unary operation at " + index);
            }
            out.append("); }\n");
        }

        private void emitCall(StringBuilder out, KofCall call, String limit, int index) {
            if (isFfiCall(call)) {
                emitFfiCall(out, call, limit, index);
                return;
            }
            if (isStringLength(call)) {
                out.append("    { KofValue receiver_").append(index)
                        .append(" = kof_pop(stack, &sp); kof_push(stack, &sp, ").append(limit)
                        .append(", kof_string_length(receiver_").append(index).append(")); }\n");
                return;
            }
            if (isStringCharAt(call)) {
                out.append("    { KofValue index_").append(index)
                        .append(" = kof_pop(stack, &sp); KofValue receiver_").append(index)
                        .append(" = kof_pop(stack, &sp); kof_push(stack, &sp, ").append(limit)
                        .append(", kof_string_char_at(receiver_").append(index)
                        .append(", kof_integral(index_").append(index).append("))); }\n");
                return;
            }
            if (isWrapperValueOf(call)) {
                out.append("    /* primitive boxing is erased by the native value representation */\n");
                return;
            }
            if (isStringValueOf(call)) {
                out.append("    { KofValue value_").append(index).append(" = kof_pop(stack, &sp);")
                        .append(" kof_push(stack, &sp, ").append(limit)
                        .append(", kof_string_value_of(value_").append(index).append(")); }\n");
                return;
            }
            if (isPrintCall(call)) {
                out.append("    { KofValue value_").append(index)
                        .append(" = kof_pop(stack, &sp); KofValue receiver_").append(index)
                        .append(" = kof_pop(stack, &sp); kof_print(receiver_").append(index)
                        .append(", value_").append(index).append(", ")
                        .append(call.methodName().equals("println") ? 1 : 0).append("); }\n");
                return;
            }
            MethodPlan target = methodsByKey.get(callKey(call));
            boolean receiverCall = switch (call.kind()) {
                case INSTANCE, INTERFACE, SUPER, CONSTRUCTOR -> true;
                case FUNCTION, STATIC -> false;
            };
            int count = call.parameterTypes().size();
            int offset = receiverCall ? 1 : 0;
            out.append("    { KofValue call_args_").append(index).append('[')
                    .append(Math.max(1, count + offset)).append("];\n");
            for (int parameter = count - 1; parameter >= 0; parameter--) {
                out.append("      call_args_").append(index).append('[').append(parameter + offset)
                        .append("] = kof_pop(stack, &sp);\n");
            }
            if (receiverCall) {
                out.append("      call_args_").append(index)
                        .append("[0] = kof_pop(stack, &sp);\n");
            }
            out.append("      KofValue call_result_").append(index).append(" = ")
                    .append(target.cName()).append("(call_args_").append(index).append(");\n");
            if (!Type.isVoid(call.returnType())) {
                out.append("      kof_push(stack, &sp, ").append(limit).append(", call_result_")
                        .append(index).append(");\n");
            } else {
                out.append("      (void)call_result_").append(index).append(";\n");
            }
            out.append("    }\n");
        }
        private void emitFfiCall(StringBuilder out, KofCall call, String limit, int index) {
            String symbol = ffiSymbol(call);
            int count = call.parameterTypes().size();
            out.append("    {");
            for (int parameter = count - 1; parameter >= 0; parameter--) {
                out.append(" KofValue ffi_arg_").append(index).append('_').append(parameter)
                        .append(" = kof_pop(stack, &sp);");
            }
            out.append('\n');
            out.append("      ");
            if (!Type.isVoid(call.returnType())) {
                out.append(cAbiType(call.returnType())).append(" ffi_result_").append(index)
                        .append(" = ");
            }
            out.append(symbol).append('(');
            for (int parameter = 0; parameter < count; parameter++) {
                if (parameter != 0) out.append(", ");
                out.append('(').append(cAbiType(call.parameterTypes().get(parameter))).append(")")
                        .append("kof_integral(ffi_arg_").append(index).append('_').append(parameter)
                        .append(')');
            }
            out.append(");\n");
            if (!Type.isVoid(call.returnType())) {
                out.append("      kof_push(stack, &sp, ").append(limit).append(", ");
                if (isBool(call.returnType())) {
                    out.append("kof_bool(ffi_result_").append(index).append(')');
                } else {
                    out.append("kof_int((int64_t)ffi_result_").append(index).append(')');
                }
                out.append(");\n");
            }
            out.append("    }\n");
        }

        private void emitEntry(StringBuilder out) {
            out.append("int kookie_kof_gameplay_main(void) {\n")
                    .append("    KofValue args[1] = { kof_array_new(0, KOF_STRING) };\n")
                    .append("    (void)").append(main.cName()).append("(args);\n")
                    .append("    if (fflush(stdout) == EOF) return 74;\n")
                    .append("    return 0;\n}\n");
            if (!library) {
                out.append("\nint main(void) {\n")
                        .append("    return kookie_kof_gameplay_main();\n}\n");
            }
        }

        private String comparisonExpression(KofComparison comparison, Type type, String left, String right) {
            if (Type.isString(type)) {
                return "kof_string_equal(" + left + ", " + right + ")" + switch (comparison) {
                    case EQ -> "";
                    case NE -> " == 0";
                    default -> throw fail("ordered String comparison is outside the PE target");
                };
            }
            String lhs = isLong(type) ? "kof_integral(" + left + ")"
                    : "kof_i32(kof_integral(" + left + "))";
            String rhs = isLong(type) ? "kof_integral(" + right + ")"
                    : "kof_i32(kof_integral(" + right + "))";
            return lhs + " " + switch (comparison) {
                case EQ -> "==";
                case NE -> "!=";
                case LT -> "<";
                case LE -> "<=";
                case GT -> ">";
                case GE -> ">=";
            } + " " + rhs;
        }

        private KofComparison toComparison(KofBinaryOp operation) {
            return switch (operation) {
                case EQ -> KofComparison.EQ;
                case NE -> KofComparison.NE;
                case LT -> KofComparison.LT;
                case LE -> KofComparison.LE;
                case GT -> KofComparison.GT;
                case GE -> KofComparison.GE;
                default -> throw fail("binary operation is not a comparison: " + operation);
            };
        }


        private boolean isIntegral(Type type) {
            return type instanceof Type.PrimitiveType primitive && switch (Type.canonicalPrimitiveName(primitive.name())) {
                case "bool", "byte", "short", "int", "long", "char" -> true;
                default -> false;
            };
        }

        private boolean isLong(Type type) {
            return type instanceof Type.PrimitiveType primitive
                    && Type.canonicalPrimitiveName(primitive.name()).equals("long");
        }

        private boolean isBool(Type type) {
            return type instanceof Type.PrimitiveType primitive
                    && Type.canonicalPrimitiveName(primitive.name()).equals("bool");
        }

        private boolean isSystemOut(KofGetStatic field) {
            return internalName(field.ownerType()).equals("java/lang/System")
                    && field.name().equals("out")
                    && internalName(field.fieldType()).equals("java/io/PrintStream");
        }

        private boolean isPrintCall(KofCall call) {
            return call.kind() == KofCallKind.INSTANCE
                    && internalName(call.ownerType()).equals("java/io/PrintStream")
                    && (call.methodName().equals("print") || call.methodName().equals("println"))
                    && call.parameterTypes().size() == 1
                    && Type.isVoid(call.returnType());
        }

        private boolean isWrapperValueOf(KofCall call) {
            String owner = internalName(call.ownerType());
            return call.kind() == KofCallKind.STATIC && call.methodName().equals("valueOf")
                    && call.parameterTypes().size() == 1
                    && Set.of("java/lang/Integer", "java/lang/Long", "java/lang/Boolean",
                            "java/lang/Byte", "java/lang/Short", "java/lang/Character").contains(owner);
        }
        private boolean isStringValueOf(KofCall call) {
            return call.kind() == KofCallKind.STATIC
                    && internalName(call.ownerType()).equals("java/lang/String")
                    && call.methodName().equals("valueOf")
                    && call.parameterTypes().size() == 1;
        }
        private boolean isStringLength(KofCall call) {
            return call.kind() == KofCallKind.INSTANCE
                    && internalName(call.ownerType()).equals("java/lang/String")
                    && call.methodName().equals("length")
                    && call.parameterTypes().isEmpty()
                    && isIntegral(call.returnType());
        }

        private boolean isStringCharAt(KofCall call) {
            return call.kind() == KofCallKind.INSTANCE
                    && internalName(call.ownerType()).equals("java/lang/String")
                    && call.methodName().equals("charAt")
                    && call.parameterTypes().size() == 1
                    && isIntegral(call.parameterTypes().get(0))
                    && isIntegral(call.returnType());
        }

        private boolean isFfiCall(KofCall call) {
            return call.kind() == KofCallKind.FUNCTION
                    && internalName(call.ownerType()).equals("kof/ffi")
                    && call.methodName().contains("::");
        }

        private String ffiSymbol(KofCall call) {
            String method = call.methodName();
            int separator = method.lastIndexOf("::");
            if (separator < 0 || separator + 2 >= method.length()) {
                throw fail("FFI call has no symbol name: " + method);
            }
            String symbol = method.substring(separator + 2);
            if (!symbol.matches("[A-Za-z_][A-Za-z0-9_]*")) {
                throw fail("FFI symbol is not a C identifier: " + symbol);
            }
            return symbol;
        }

        private void registerFfi(KofCall call) {
            validateFfiSignature(call);
            String symbol = ffiSymbol(call);
            KofCall previous = ffiCalls.putIfAbsent(symbol, call);
            if (previous != null && (!previous.parameterTypes().equals(call.parameterTypes())
                    || !previous.returnType().equals(call.returnType()))) {
                throw fail("FFI symbol has incompatible signatures: " + symbol);
            }
        }

        private void validateFfiSignature(KofCall call) {
            if (call.kind() != KofCallKind.FUNCTION) {
                throw fail("FFI calls must use the function call convention");
            }
            for (Type parameter : call.parameterTypes()) {
                if (!isIntegral(parameter)) {
                    throw fail("FFI parameter type is outside the integral ABI: "
                            + Type.display(parameter));
                }
            }
            if (!Type.isVoid(call.returnType()) && !isIntegral(call.returnType())) {
                throw fail("FFI return type is outside the integral ABI: "
                        + Type.display(call.returnType()));
            }
        }

        private boolean supportedValueType(Type type, boolean allowVoid) {
            return (allowVoid && Type.isVoid(type))
                    || isIntegral(type)
                    || Type.isString(type)
                    || type instanceof Type.ClassType
                    || type instanceof Type.ArrayType;
        }
        private boolean isSupportedExternal(KofCall call) {
            return isPrintCall(call) || isWrapperValueOf(call) || isStringValueOf(call)
                    || isStringLength(call) || isStringCharAt(call) || isFfiCall(call);
        }

        private boolean hasReceiver(IRMethod method) {
            return method.name().equals("<init>") || (method.accessFlags() & 0x0008) == 0;
        }

        private String fieldKey(String owner, String name, Type type) {
            return owner + "|" + name + "|" + type;
        }
        private int fieldIndex(Type owner, String name, Type type) {
            Integer index = fieldIndexes.get(fieldKey(internalName(owner), name, type));
            if (index == null) throw fail("field is outside the reachable PE module");
            return index;
        }

        private String tagFor(Type type) {
            if (isBool(type)) return "KOF_BOOL";
            if (isIntegral(type)) return "KOF_INT";
            if (Type.isString(type)) return "KOF_STRING";
            if (type instanceof Type.ArrayType) return "KOF_ARRAY";
            if (type instanceof Type.ClassType) return "KOF_OBJECT";
            return "KOF_NIL";
        }

        private MethodKey callKey(KofCall call) {
            return new MethodKey(internalName(call.ownerType()), call.methodName(), call.parameterTypes());
        }

        private String internalName(Type type) {
            return type instanceof Type.ClassType cls ? cls.internalName() : "";
        }

        private void requireLabel(MethodPlan plan, Set<Integer> labels, int id) {
            if (!labels.contains(id)) throw fail(plan.method().name() + " jumps to missing label " + id);
        }

        private PeFailure unsupported(MethodPlan plan, int index, KofOperation operation, String reason) {
            return fail(plan.method().name() + " operation " + index + " ("
                    + operation.getClass().getSimpleName() + "): " + reason);
        }

        private PeFailure fail(String message) {
            return new PeFailure(message);
        }

        private String display(MethodKey key) {
            return key.owner() + "." + key.name() + key.parameters();
        }
    }

    private record MethodKey(String owner, String name, List<Type> parameters) {
        MethodKey {
            parameters = List.copyOf(parameters);
        }
    }

    private static final class ClassPlan {
        private final String owner;
        private final List<IRField> fields;

        ClassPlan(String owner, List<IRField> fields) {
            this.owner = owner;
            this.fields = List.copyOf(fields);
        }

        String owner() { return owner; }
        List<IRField> fields() { return fields; }
    }

    private static final class MethodPlan {
        private final String owner;
        private final IRMethod method;
        private final String cName;
        private final List<KofOperation> operations;
        private final boolean hasReceiver;
        private int localCount;
        private int maxStack;

        MethodPlan(String owner, IRMethod method, String cName,
                   List<KofOperation> operations, boolean hasReceiver) {
            this.owner = owner;
            this.method = method;
            this.cName = cName;
            this.operations = operations;
            this.hasReceiver = hasReceiver;
        }

        String owner() { return owner; }
        IRMethod method() { return method; }
        String cName() { return cName; }
        List<KofOperation> operations() { return operations; }
        boolean hasReceiver() { return hasReceiver; }
        int localCount() { return localCount; }
        void localCount(int value) { localCount = value; }
        int maxStack() { return maxStack; }
        void maxStack(int value) { maxStack = value; }
    }

    private static final class PeFailure extends RuntimeException {
        private static final long serialVersionUID = 1L;

        PeFailure(String message) {
            super(message);
        }
    }
}
