const std = @import("std");

const FunctionInfo = struct {
    name: []const u8,
    params: std.ArrayList(ParameterInfo),
    return_type: ?[]const u8,

    pub fn deinit(self: *FunctionInfo, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        for (self.params.items) |*param| {
            param.deinit(allocator);
        }
        self.params.deinit();
        if (self.return_type) |rt| {
            allocator.free(rt);
        }
    }
};

const StructInfo = struct {
    name: []const u8,
    params: std.ArrayList(ParameterInfo),

    pub fn deinit(self: *FunctionInfo, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        for (self.params.items) |*param| {
            param.deinit(allocator);
        }
        self.params.deinit();
    }
};

const ParameterInfo = struct {
    name: []const u8,
    type: []const u8,

    pub fn deinit(self: *ParameterInfo, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.type);
    }
};

const AstEmitter = struct {
    ast: *std.zig.Ast,
    allocator: std.mem.Allocator,
    function_infos: std.ArrayList(FunctionInfo) = undefined,
    struct_infos: std.ArrayList(StructInfo) = undefined,

    pub fn init(allocator: std.mem.Allocator, ast: *std.zig.Ast) @This() {
        return .{
            .allocator = allocator,
            .ast = ast,
            .function_infos = std.ArrayList(FunctionInfo).init(allocator),
        };
    }

    pub fn deinit(self: *@This()) void {
        for (self.function_infos.items) |*func_info| {
            func_info.deinit(self.allocator);
        }
        self.function_infos.deinit();
    }

    fn copySlice(self: *@This(), slice: []const u8) ![]const u8 {
        const buffer = try self.allocator.alloc(u8, slice.len);
        std.mem.copyForwards(u8, buffer, slice);
        return buffer;
    }

    pub fn emitRoot(self: *@This()) !void {
        for (0..self.ast.nodes.len) |i| {
            const idx: u32 = @intCast(i);
            try self.emitNode(idx);
        }
    }

    fn emitNode(self: *@This(), node_idx: std.zig.Ast.Node.Index) !void {
        const n = self.ast.nodes.get(node_idx);
        std.log.info("Tag: {any}", .{n.tag});
        switch (n.tag) {
            .fn_decl => {
                try self.fnDecl(node_idx);
            },
            .identifier => {
                try self.structProto(node_idx);
            },
            else => {},
        }
    }

    fn fnDecl(self: *@This(), node_idx: std.zig.Ast.Node.Index) !void {
        var buffer: [1]std.zig.Ast.Node.Index = undefined;
        if (self.ast.fullFnProto(&buffer, node_idx)) |p| {
            try self.fnProto(p);
        }
    }

    fn structProto(self: *@This(), idx: std.zig.Ast.Node.Index) !void {
        _ = StructInfo{
            .name = undefined,
            .params = std.ArrayList(ParameterInfo).init(self.allocator),
        };

        const node = self.ast.nodes.get(idx);
        //const struct_node = std.zig.Ast.structInit(self.ast.*, idx);

        // Get struct name
        const name_token_idx = 2;
        const name_slice = self.ast.tokenSlice(name_token_idx);
        std.log.info("proto {s} {any} {any}", .{name_slice, idx, node});
        //std.log.info("{any}", .{struct_node});

        //struct_info.name = try self.copySlice(name_slice);

        //try self.struct_infos.append(struct_info);
    }

    fn fnProto(self: *@This(), proto: std.zig.Ast.full.FnProto) !void {
        var function_info = FunctionInfo{
            .name = undefined,
            .params = std.ArrayList(ParameterInfo).init(self.allocator),
            .return_type = null,
        };

        // Get function name
        const name_token_idx = proto.ast.fn_token + 1;
        const name_slice = self.ast.tokenSlice(name_token_idx);
        function_info.name = try self.copySlice(name_slice);

        // Iterate over parameters
        var param_it = proto.iterate(self.ast);
        while (param_it.next()) |param| {
            var param_info = ParameterInfo{
                .name = undefined,
                .type = undefined,
            };

            // Get parameter name
            if (param.name_token) |nt| {
                param_info.name = try self.copySlice(self.ast.tokenSlice(nt));
            } else {
                param_info.name = try self.copySlice("");
            }

            // Get parameter type
            param_info.type = try self.getTypeExpr(param.type_expr);

            // Append param_info to function_info.params
            try function_info.params.append(param_info);
        }

        // Get return type
        if (proto.ast.return_type != 0) {
            function_info.return_type = try self.getTypeExpr(proto.ast.return_type);
        } else {
            function_info.return_type = null;
        }

        // Append function_info to self.function_infos
        try self.function_infos.append(function_info);
    }

    fn getTypeExpr(self: *@This(), node_idx: std.zig.Ast.Node.Index) ![]const u8 {
        const n = self.ast.nodes.get(node_idx);
        switch (n.tag) {
            .identifier => {
                const type_name = self.ast.tokenSlice(n.main_token);
                return try self.copySlice(type_name);
            },
            else => {
                return try self.copySlice("unknown");
            },
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const src =
        \\pub fn test_function(i: u8, j: u16) !u8 {};
        \\pub const Player = struct {
        \\    x: i32,
        \\    score: i32 = 0,
        \\};
    ;

    var ast = std.zig.Ast.parse(allocator, src, .zig) catch {
        std.debug.print("failed to parse source file.", .{});
        return;
    };
    defer ast.deinit(allocator);

    var emit = AstEmitter.init(allocator, &ast);
    defer emit.deinit();

    try emit.emitRoot();

    for (emit.function_infos.items) |func_info| {
        std.debug.print("Function: {s}\n", .{func_info.name});
        for (func_info.params.items) |param_info| {
            std.debug.print("  Param: {s}: {s}\n", .{ param_info.name, param_info.type });
        }
        if (func_info.return_type) |rt| {
            std.debug.print("  Returns: {s}\n", .{rt});
        }
    }
    //for (emit.struct_infos.items) |struct_info| {
    //    std.debug.print("Struct: {s}\n", .{struct_info.name});
    //for (func_info.params.items) |param_info| {
    //    std.debug.print("  Param: {s}: {s}\n", .{ param_info.name, param_info.type });
    //}
    //}
}
