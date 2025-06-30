const std = @import("std");

pub fn is_alsa_playing() !bool {
    var argv = [_][]const u8{ "sh", "-c", "grep RUNNING /proc/asound/card*/pcm*/sub*/status" };
    const result = try std.process.Child.run(.{ .allocator = std.heap.page_allocator, .argv = &argv });

    // std.debug.print("stderr={s}\n", .{result.stderr});
    // std.debug.print("stdout={s}\n", .{result.stdout});

    return result.stdout.len != 0;
}
