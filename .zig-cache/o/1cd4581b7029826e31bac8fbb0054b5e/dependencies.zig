pub const packages = struct {
    pub const @"aro-0.0.0-JSD1QqKGNwALqBes402gHE7CP3Ga6xHS1J4mjThB3ro4" = struct {
        pub const build_root = "zig-pkg/aro-0.0.0-JSD1QqKGNwALqBes402gHE7CP3Ga6xHS1J4mjThB3ro4";
        pub const build_zig = @import("aro-0.0.0-JSD1QqKGNwALqBes402gHE7CP3Ga6xHS1J4mjThB3ro4");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
        };
    };
    pub const @"translate_c-2.0.1-Q_BUWmpOBwCIhy--up1q6cl3OlIQE86iJU8R-bZ01aPj" = struct {
        pub const build_root = "zig-pkg/translate_c-2.0.1-Q_BUWmpOBwCIhy--up1q6cl3OlIQE86iJU8R-bZ01aPj";
        pub const build_zig = @import("translate_c-2.0.1-Q_BUWmpOBwCIhy--up1q6cl3OlIQE86iJU8R-bZ01aPj");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
            .{ "aro", "aro-0.0.0-JSD1QqKGNwALqBes402gHE7CP3Ga6xHS1J4mjThB3ro4" },
        };
    };
};

pub const root_deps: []const struct { []const u8, []const u8 } = &.{
    .{ "translate_c", "translate_c-2.0.1-Q_BUWmpOBwCIhy--up1q6cl3OlIQE86iJU8R-bZ01aPj" },
};
