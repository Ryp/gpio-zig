const std = @import("std");

const c = @cImport({
    @cInclude("gpiod.h");
});

const MyErrors = error{
    ChipOpenError,
    LineInfoError,
    AddLineSettingsError,
    LineSettingsSetError,
    SetValueError,
};

pub fn main() !void {
    const chip_device_path = "/dev/gpiochip0";
    const line_num: u32 = 17; // GPIO 17 on a Raspi4

    // NOTE: Need proper rights to be able to do that
    const chip = c.gpiod_chip_open(chip_device_path) orelse return MyErrors.ChipOpenError;
    defer c.gpiod_chip_close(chip);

    try print_line_status(chip, line_num);

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

    if (c.gpiod_line_request_set_value(line_request, line_num, c.GPIOD_LINE_VALUE_ACTIVE) < 0) {
        return MyErrors.SetValueError;
    }

    if (c.gpiod_line_request_set_value(line_request, line_num, c.GPIOD_LINE_VALUE_INACTIVE) < 0) {
        return MyErrors.SetValueError;
    }

    if (c.gpiod_line_request_set_value(line_request, line_num, c.GPIOD_LINE_VALUE_ACTIVE) < 0) {
        return MyErrors.SetValueError;
    }

    std.time.sleep(10000000000);

    try print_line_status(chip, line_num);
}

pub fn print_line_status(chip: *c.gpiod_chip, line_number: u32) !void {
    const line_info = c.gpiod_chip_get_line_info(chip, line_number) orelse return MyErrors.LineInfoError;
    defer c.gpiod_line_info_free(line_info);

    const line_name = c.gpiod_line_info_get_name(line_info);
    std.debug.print("Line: {s}\n", .{line_name});

    const line_direction = c.gpiod_line_info_get_direction(line_info);
    std.debug.print("Direction: {s}\n", .{if (line_direction == c.GPIOD_LINE_DIRECTION_INPUT) "input" else "output"});

    const line_used = c.gpiod_line_info_is_used(line_info);
    std.debug.print("Used: {s}\n", .{if (line_used) "yes" else "no"});
}
