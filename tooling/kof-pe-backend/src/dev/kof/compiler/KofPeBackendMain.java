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

/**
 * Strict Kof IR to C11 lowering for the bounded Windows PE/COFF target.
 *
 * <p>The class deliberately lives in the compiler package. Kof 0.5.0-beta does
 * not expose a public optimized-IR frontend API, so this tool is pinned to the
 * exact Kof source revision enforced by the launcher. Unsupported IR is a
 * PE001 build error; it is never replaced with a stub.
 */
public final class KofPeBackendMain {
    private static final int MAX_METHODS = 256;
    private static final int MAX_OPERATIONS = 16_384;
    private static final int MAX_LOCALS = 256;
    private static final int MAX_STACK = 256;

    private KofPeBackendMain() {}

    public static void main(String[] args) {
        if (args.length != 2) {
            System.err.println("Usage: KofPeBackendMain <source.kf|directory> <generated.c>");
            System.exit(2);
        }
        try {
            Path source = Path.of(args[0]).toAbsolutePath().normalize();
            Path output = Path.of(args[1]).toAbsolutePath().normalize();
            List<Path> sources = collectSources(source);
            IRModule module = lower(sources);
            String generated = new CEmitter(module).emit();
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
        private final List<MethodPlan> methods = new ArrayList<>();
        private final Map<MethodKey, MethodPlan> methodsByKey = new LinkedHashMap<>();
        private final Map<String, Integer> strings = new LinkedHashMap<>();
        private MethodPlan main;

        CEmitter(IRModule module) {
            this.module = module;
        }

        String emit() {
            planModule();
            StringBuilder out = new StringBuilder(32_768);
            emitPreamble(out);
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
            if (module.classes().size() != 1) {
                throw fail("bounded target accepts only the generated top-level Main class; found "
                        + module.classes().size() + " classes");
            }
            IRClass owner = module.classes().get(0);
            String expectedOwner = module.name().isEmpty() ? "Main" : module.name() + "/Main";
            if (!owner.name().equals(expectedOwner)) {
                throw fail("expected top-level class " + expectedOwner + "; found " + owner.name());
            }
            if (!owner.fields().isEmpty()) throw fail("fields are outside the bounded PE subset");
            if (owner.methods().size() > MAX_METHODS) {
                throw fail("method count exceeds " + MAX_METHODS);
            }
            int ordinal = 0;
            for (IRMethod method : owner.methods()) {
                if (method.name().startsWith("<")) {
                    throw fail("constructors and class initializers are outside the bounded PE subset");
                }
                MethodKey key = new MethodKey(owner.name(), method.name(), method.parameterTypes());
                MethodPlan plan = new MethodPlan(owner.name(), method, "kof_method_" + ordinal++, flatten(method));
                if (methodsByKey.put(key, plan) != null) {
                    throw fail("duplicate method signature " + display(key));
                }
                methods.add(plan);
                if (method.name().equals("main")) {
                    if (main != null) throw fail("multiple main methods are unsupported");
                    main = plan;
                }
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
                } else if (operation instanceof KofBinary binary) {
                    if (!isIntegral(binary.operandType())) {
                        throw unsupported(plan, index, operation, "only integral binary operations are supported");
                    }
                } else if (operation instanceof KofUnary unary) {
                    validateUnary(plan, index, unary);
                } else if (operation instanceof KofConditionalJump jump) {
                    if (!isIntegral(jump.operandType())) {
                        throw unsupported(plan, index, operation, "only integral comparisons are supported");
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
                } else if (operation instanceof KofReturnVoid
                        || operation instanceof KofLabel
                        || operation instanceof KofStatementIf
                        || operation instanceof KofPop
                        || operation instanceof KofDup) {
                    // Supported structural or stack operation.
                } else {
                    throw unsupported(plan, index, operation, "operation is outside the bounded PE subset");
                }
            }
        }

        private void validateLiteral(MethodPlan plan, KofLoadLiteral literal) {
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
            if (target == null || (call.kind() != KofCallKind.FUNCTION && call.kind() != KofCallKind.STATIC)) {
                throw unsupported(plan, index, call, "only top-level static Kof function calls are supported");
            }
            if (!target.method().returnType().equals(call.returnType())) {
                throw unsupported(plan, index, call, "call return type does not match its target");
            }
        }

        private int verifyControlFlow(MethodPlan plan) {
            List<KofOperation> operations = plan.operations();
            if (operations.isEmpty()) throw fail(plan.method().name() + " has no operations");
            Map<Integer, Integer> labelIndexes = new HashMap<>();
            for (int index = 0; index < operations.size(); index++) {
                if (operations.get(index) instanceof KofLabel label) {
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
                    || operation instanceof KofGetStatic || operation instanceof KofDup) return 1;
            if (operation instanceof KofStoreLocal || operation instanceof KofPop
                    || operation instanceof KofReturn) return -1;
            if (operation instanceof KofBinary) return -1;
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
                    || operation instanceof KofDup) return 1;
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
            out.append("/* Generated from optimized Kof IR by the pinned bounded PE/COFF backend. */\n")
                    .append("#include <stdint.h>\n#include <stddef.h>\n#include <stdio.h>\n#include <stdlib.h>\n\n")
                    .append("#if defined(__GNUC__)\n#define KOF_UNUSED __attribute__((unused))\n#else\n#define KOF_UNUSED\n#endif\n\n")
                    .append("typedef enum { KOF_NIL = 0, KOF_INT = 1, KOF_BOOL = 2, KOF_STRING = 3, KOF_OUT = 4 } KofTag;\n")
                    .append("typedef struct { KofTag tag; uint64_t bits; const unsigned char *bytes; size_t length; } KofValue;\n\n")
                    .append("static KOF_UNUSED void kof_fail(const char *message) {\n")
                    .append("    fputs(\"kof-pe runtime: \", stderr); fputs(message, stderr); fputc('\\n', stderr); exit(70);\n}\n")
                    .append("static KOF_UNUSED KofValue kof_nil(void) { return (KofValue){KOF_NIL, 0, NULL, 0}; }\n")
                    .append("static KOF_UNUSED KofValue kof_int(int64_t value) { return (KofValue){KOF_INT, (uint64_t)value, NULL, 0}; }\n")
                    .append("static KOF_UNUSED KofValue kof_bool(int value) { return (KofValue){KOF_BOOL, value ? 1u : 0u, NULL, 0}; }\n")
                    .append("static KOF_UNUSED KofValue kof_string(const unsigned char *bytes, size_t length) { return (KofValue){KOF_STRING, 0, bytes, length}; }\n")
                    .append("static KOF_UNUSED KofValue kof_out(void) { return (KofValue){KOF_OUT, 0, NULL, 0}; }\n")
                    .append("static KOF_UNUSED void kof_push(KofValue *stack, size_t *sp, size_t limit, KofValue value) {\n")
                    .append("    if (*sp >= limit) kof_fail(\"value stack overflow\");\n")
                    .append("    stack[(*sp)++] = value;\n}\n")
                    .append("static KOF_UNUSED KofValue kof_pop(KofValue *stack, size_t *sp) {\n")
                    .append("    if (*sp == 0) kof_fail(\"value stack underflow\");\n")
                    .append("    return stack[--(*sp)];\n}\n")
                    .append("static KOF_UNUSED int64_t kof_integral(KofValue value) {\n")
                    .append("    if (value.tag != KOF_INT && value.tag != KOF_BOOL) kof_fail(\"expected integral value\");\n")
                    .append("    return (int64_t)value.bits;\n}\n")
                    .append("static KOF_UNUSED int32_t kof_i32(int64_t value) { return (int32_t)(uint32_t)value; }\n")
                    .append("static KOF_UNUSED int64_t kof_add32(int64_t a, int64_t b) { return kof_i32((uint32_t)a + (uint32_t)b); }\n")
                    .append("static KOF_UNUSED int64_t kof_sub32(int64_t a, int64_t b) { return kof_i32((uint32_t)a - (uint32_t)b); }\n")
                    .append("static KOF_UNUSED int64_t kof_mul32(int64_t a, int64_t b) { return kof_i32((uint32_t)a * (uint32_t)b); }\n")
                    .append("static KOF_UNUSED int64_t kof_div32(int64_t a, int64_t b) {\n")
                    .append("    int32_t x = kof_i32(a), y = kof_i32(b);\n")
                    .append("    if (y == 0) kof_fail(\"division by zero\");\n")
                    .append("    if (x == INT32_MIN && y == -1) return INT32_MIN;\n")
                    .append("    return x / y;\n}\n")
                    .append("static KOF_UNUSED int64_t kof_mod32(int64_t a, int64_t b) {\n")
                    .append("    int32_t x = kof_i32(a), y = kof_i32(b);\n")
                    .append("    if (y == 0) kof_fail(\"division by zero\");\n")
                    .append("    if (x == INT32_MIN && y == -1) return 0;\n")
                    .append("    return x % y;\n}\n")
                    .append("static KOF_UNUSED int64_t kof_div64(int64_t a, int64_t b) {\n")
                    .append("    if (b == 0) kof_fail(\"division by zero\");\n")
                    .append("    if (a == INT64_MIN && b == -1) return INT64_MIN;\n")
                    .append("    return a / b;\n}\n")
                    .append("static KOF_UNUSED int64_t kof_mod64(int64_t a, int64_t b) {\n")
                    .append("    if (b == 0) kof_fail(\"division by zero\");\n")
                    .append("    if (a == INT64_MIN && b == -1) return 0;\n")
                    .append("    return a % b;\n}\n")
                    .append("static KOF_UNUSED int64_t kof_shr32(int64_t a, int64_t b) {\n")
                    .append("    uint32_t x = (uint32_t)a, n = (uint32_t)b & 31u;\n")
                    .append("    if (n == 0) return kof_i32(x);\n")
                    .append("    return kof_i32((x >> n) | ((x & 0x80000000u) ? (~UINT32_C(0) << (32u - n)) : 0u));\n}\n")
                    .append("static KOF_UNUSED int64_t kof_shr64(int64_t a, int64_t b) {\n")
                    .append("    uint64_t x = (uint64_t)a, n = (uint64_t)b & 63u;\n")
                    .append("    if (n == 0) return (int64_t)x;\n")
                    .append("    return (int64_t)((x >> n) | ((x & UINT64_C(0x8000000000000000)) ? (~UINT64_C(0) << (64u - n)) : 0u));\n}\n")
                    .append("static KOF_UNUSED void kof_print(KofValue out, KofValue value, int newline) {\n")
                    .append("    if (out.tag != KOF_OUT) kof_fail(\"invalid print receiver\");\n")
                    .append("    if (value.tag == KOF_STRING) { if (value.length && fwrite(value.bytes, 1, value.length, stdout) != value.length) kof_fail(\"stdout write failed\"); }\n")
                    .append("    else if (value.tag == KOF_BOOL) { if (fputs(value.bits ? \"true\" : \"false\", stdout) < 0) kof_fail(\"stdout write failed\"); }\n")
                    .append("    else if (value.tag == KOF_INT) { if (fprintf(stdout, \"%lld\", (long long)(int64_t)value.bits) < 0) kof_fail(\"stdout write failed\"); }\n")
                    .append("    else kof_fail(\"unsupported printable value\");\n")
                    .append("    if (newline && fputc('\\n', stdout) == EOF) kof_fail(\"stdout write failed\");\n}\n\n");
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
                    .append("    for (size_t i = 0; i < ").append(plan.localCount()).append("; ++i) locals[i] = kof_nil();\n")
                    .append("    (void)locals;\n")
                    .append("    (void)args;\n");
            if (plan != main) {
                for (int index = 0; index < method.parameterTypes().size(); index++) {
                    out.append("    locals[").append(index).append("] = args[").append(index).append("];\n");
                }
            }
            List<KofOperation> operations = plan.operations();
            Set<Integer> referencedLabels = referencedLabels(operations);
            for (int index = 0; index < operations.size(); index++) {
                emitOperation(out, plan, index, operations.get(index), referencedLabels);
            }
            out.append("}\n\n");
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
                                   KofOperation operation, Set<Integer> referencedLabels) {
            String limit = Integer.toString(plan.maxStack());
            if (operation instanceof KofLoadLiteral literal) {
                if (literal.value() instanceof String value) {
                    int id = strings.get(value);
                    int length = value.getBytes(StandardCharsets.UTF_8).length;
                    out.append("    kof_push(stack, &sp, ").append(limit).append(", kof_string(kof_string_")
                            .append(id).append(", ").append(length).append("));\n");
                } else {
                    long value = ((Number) literal.value()).longValue();
                    if (isBool(literal.type())) {
                        out.append("    kof_push(stack, &sp, ").append(limit).append(", kof_bool(")
                                .append(value == 0 ? 0 : 1).append("));\n");
                    } else {
                        out.append("    kof_push(stack, &sp, ").append(limit).append(", kof_int(INT64_C(")
                                .append(value).append(")));\n");
                    }
                }
            } else if (operation instanceof KofLoadLocal local) {
                out.append("    kof_push(stack, &sp, ").append(limit).append(", locals[")
                        .append(local.index()).append("]);\n");
            } else if (operation instanceof KofStoreLocal local) {
                out.append("    locals[").append(local.index()).append("] = kof_pop(stack, &sp);\n");
            } else if (operation instanceof KofBinary binary) {
                emitBinary(out, binary, limit, index);
            } else if (operation instanceof KofUnary unary) {
                emitUnary(out, unary, limit, index);
            } else if (operation instanceof KofConditionalJump jump) {
                out.append("    { int64_t right = kof_integral(kof_pop(stack, &sp)); int64_t left = kof_integral(kof_pop(stack, &sp));\n")
                        .append("      if (").append(comparisonExpression(jump.comparison(), jump.operandType(), "left", "right"))
                        .append(") goto kof_label_").append(jump.trueLabel().id())
                        .append("; else goto kof_label_").append(jump.falseLabel().id()).append("; }\n");
            } else if (operation instanceof KofJump jump) {
                out.append("    goto kof_label_").append(jump.target().id()).append(";\n");
            } else if (operation instanceof KofLabel label) {
                if (referencedLabels.contains(label.label().id())) {
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
                out.append("    { KofValue value = kof_pop(stack, &sp); kof_push(stack, &sp, ")
                        .append(limit).append(", value); kof_push(stack, &sp, ").append(limit)
                        .append(", value); }\n");
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
                        .append(comparisonExpression(toComparison(binary.op()), binary.operandType(), "left", "right")).append(')');
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
            if (isWrapperValueOf(call) || isStringValueOf(call)) {
                out.append("    /* compiler print coercion; KofValue retains its exact runtime tag */\n");
                return;
            }
            if (isPrintCall(call)) {
                out.append("    { KofValue value = kof_pop(stack, &sp); KofValue receiver = kof_pop(stack, &sp); kof_print(receiver, value, ")
                        .append(call.methodName().equals("println") ? 1 : 0).append("); }\n");
                return;
            }
            MethodPlan target = methodsByKey.get(callKey(call));
            int count = call.parameterTypes().size();
            out.append("    { KofValue call_args_").append(index).append('[').append(Math.max(1, count)).append("];\n");
            for (int parameter = count - 1; parameter >= 0; parameter--) {
                out.append("      call_args_").append(index).append('[').append(parameter)
                        .append("] = kof_pop(stack, &sp);\n");
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

        private void emitEntry(StringBuilder out) {
            out.append("int main(void) {\n")
                    .append("    KofValue args[1] = { kof_nil() };\n")
                    .append("    (void)").append(main.cName()).append("(args);\n")
                    .append("    if (fflush(stdout) == EOF) return 74;\n")
                    .append("    return 0;\n}\n");
        }

        private String comparisonExpression(KofComparison comparison, Type type, String left, String right) {
            String lhs = isLong(type) ? left : "kof_i32(" + left + ")";
            String rhs = isLong(type) ? right : "kof_i32(" + right + ")";
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

        private boolean supportedValueType(Type type, boolean allowVoid) {
            return (allowVoid && Type.isVoid(type)) || isIntegral(type) || Type.isString(type);
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

    private static final class MethodPlan {
        private final String owner;
        private final IRMethod method;
        private final String cName;
        private final List<KofOperation> operations;
        private int localCount;
        private int maxStack;

        MethodPlan(String owner, IRMethod method, String cName, List<KofOperation> operations) {
            this.owner = owner;
            this.method = method;
            this.cName = cName;
            this.operations = operations;
        }

        String owner() { return owner; }
        IRMethod method() { return method; }
        String cName() { return cName; }
        List<KofOperation> operations() { return operations; }
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
