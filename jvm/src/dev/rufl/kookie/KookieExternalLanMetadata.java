package dev.rufl.kookie;

import java.io.IOException;
import java.net.InetAddress;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.List;
import java.util.regex.Pattern;

/** Writes the role identity markers consumed by the external LAN evidence validator. */
public final class KookieExternalLanMetadata {
    private static final Pattern RUN_ID_PATTERN =
            Pattern.compile("[A-Za-z0-9][A-Za-z0-9._-]{7,127}");
    private static final List<String> ROLES = List.of("host", "client-a", "client-b");

    private KookieExternalLanMetadata() {}

    public static void main(String[] args) {
        if (args.length != 3) {
            fail("usage: KookieExternalLanMetadata LOG ROLE EXIT_STATUS");
        }
        int status;
        try {
            status = Integer.parseInt(args[2]);
        } catch (NumberFormatException error) {
            fail("exit status must be an integer");
            return;
        }
        try {
            record(Path.of(args[0]), args[1], status);
        } catch (IOException | IllegalArgumentException error) {
            fail(error.getMessage());
        }
    }

    public static void record(Path logPath, String role, int exitStatus) throws IOException {
        if (!ROLES.contains(role)) {
            throw new IllegalArgumentException("unsupported role: " + role);
        }
        if (!Files.isRegularFile(logPath)) {
            throw new IllegalArgumentException("missing role log: " + logPath);
        }
        String runId = requiredEnvironment("KOOKIE_EXTERNAL_LAN_RUN_ID");
        if (!RUN_ID_PATTERN.matcher(runId).matches()) {
            throw new IllegalArgumentException(
                    "KOOKIE_EXTERNAL_LAN_RUN_ID must be 8-128 safe identifier characters");
        }
        String keyHex = requiredEnvironment("KOOKIE_TRANSPORT_KEY_HEX");
        if (keyHex.length() != 32 || !keyHex.matches("[0-9a-fA-F]{32}")) {
            throw new IllegalArgumentException(
                    "KOOKIE_TRANSPORT_KEY_HEX must be 32 hexadecimal characters");
        }
        String hostname = hostname();
        String machineDigest = sha256("kookie-machine:" + machineIdentity(hostname));
        String keyDigest = sha256(keyHex);
        String hostIpv4 = System.getenv().getOrDefault("KOOKIE_EXTERNAL_LAN_HOST_IPV4", "127.0.0.1");
        String lines = "external-role-run-id=" + role + ":" + runId + "\n"
                + "external-role-identity=" + role + ":" + hostname + "\n"
                + "external-role-machine-fingerprint=" + role + ":" + machineDigest + "\n"
                + "external-role-key-sha256=" + role + ":" + keyDigest + "\n"
                + "external-role-host-ipv4=" + role + ":" + hostIpv4 + "\n"
                + "external-" + role + "-exit-status\n" + exitStatus + "\n";
        Files.writeString(logPath, lines, StandardCharsets.UTF_8,
                StandardOpenOption.CREATE, StandardOpenOption.APPEND);
        System.out.println("{\"role\":\"" + json(role)
                + "\",\"runId\":\"" + json(runId)
                + "\",\"manifest\":\""
                + json(System.getenv().getOrDefault("KOOKIE_EXTERNAL_LAN_RUN_MANIFEST", ""))
                + "\",\"hostname\":\"" + json(hostname)
                + "\",\"machineFingerprint\":\"" + machineDigest
                + "\",\"keySha256\":\"" + keyDigest
                + "\",\"hostIpv4\":\"" + json(hostIpv4)
                + "\",\"exitStatus\":" + exitStatus
                + ",\"log\":\"" + json(logPath.toString()) + "\"}");
    }

    private static String requiredEnvironment(String name) {
        String value = System.getenv(name);
        if (value == null || value.isEmpty()) {
            throw new IllegalArgumentException(name + " is required");
        }
        return value;
    }

    private static String hostname() {
        String value = System.getenv("COMPUTERNAME");
        if (value == null || value.isBlank()) {
            value = System.getenv("HOSTNAME");
        }
        if (value == null || value.isBlank()) {
            try {
                value = InetAddress.getLocalHost().getHostName();
            } catch (IOException ignored) {
                value = "unknown";
            }
        }
        return value.trim().isEmpty() ? "unknown" : value.trim();
    }

    private static String machineIdentity(String hostname) {
        for (String candidate : List.of("/etc/machine-id", "/var/lib/dbus/machine-id")) {
            try {
                if (Files.isRegularFile(Path.of(candidate))) {
                    String value = Files.readString(Path.of(candidate), StandardCharsets.UTF_8).trim();
                    if (!value.isEmpty()) {
                        return value;
                    }
                }
            } catch (IOException ignored) {
                // Fall through to the platform identity available on Windows and other hosts.
            }
        }
        return hostname + "|" + System.getProperty("os.name", "unknown") + "|"
                + System.getProperty("os.version", "unknown") + "|"
                + System.getProperty("os.arch", "unknown");
    }

    private static String sha256(String value) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256")
                    .digest(value.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException error) {
            throw new IllegalStateException("SHA-256 unavailable", error);
        }
    }

    private static String json(String value) {
        return value.replace("\\", "\\\\").replace("\"", "\\\"")
                .replace("\r", "\\r").replace("\n", "\\n");
    }

    private static void fail(String message) {
        System.err.println("external LAN role metadata failed: " + message);
        System.exit(1);
    }
}
