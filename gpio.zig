const std = @import("std");

const c = @cImport({
    @cInclude("gpiod.h");
});

const MyErrors = error{
    ChipOpenError,
    LineInfoError,
    LineUsed,
    AddLineSettingsError,
    LineSettingsSetError,
};

pub fn main() !void {
    const chip_device_path = "/dev/gpiochip0";

    // NOTE: Need proper rights to be able to do that
    const chip = c.gpiod_chip_open(chip_device_path) orelse return MyErrors.ChipOpenError;
    defer c.gpiod_chip_close(chip);

    const line_num: u32 = 17;

    {
        const line_info = c.gpiod_chip_get_line_info(chip, line_num) orelse return MyErrors.LineInfoError;
        defer c.gpiod_line_info_free(line_info);

        const line_name = c.gpiod_line_info_get_name(line_info);
        std.debug.print("Line: {s}\n", .{line_name});

        const line_direction = c.gpiod_line_info_get_direction(line_info);
        std.debug.print("Direction: {s}\n", .{if (line_direction == c.GPIOD_LINE_DIRECTION_INPUT) "input" else "output"});

        if (c.gpiod_line_info_is_used(line_info)) {
            return MyErrors.LineUsed;
        }
    }

    var line_settings = c.gpiod_line_settings_new();
    defer c.gpiod_line_settings_free(line_settings);

    if (c.gpiod_line_settings_set_direction(line_settings, c.GPIOD_LINE_DIRECTION_OUTPUT) < 0) {
        return MyErrors.LineSettingsSetError;
    }

    var line_config = c.gpiod_line_config_new();
    defer c.gpiod_line_config_free(line_config);

    if (c.gpiod_line_config_add_line_settings(line_config, &line_num, 1, line_settings) < 0) {
        return MyErrors.AddLineSettingsError;
    }

    const line_request = c.gpiod_chip_request_lines(chip, null, line_config);
    defer c.gpiod_line_request_release(line_request);

    {
        const line_info = c.gpiod_chip_get_line_info(chip, line_num) orelse return MyErrors.LineInfoError;
        defer c.gpiod_line_info_free(line_info);

        const line_direction = c.gpiod_line_info_get_direction(line_info);
        std.debug.print("Direction: {s}\n", .{if (line_direction == c.GPIOD_LINE_DIRECTION_INPUT) "input" else "output"});
    }
}
