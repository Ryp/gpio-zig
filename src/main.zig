const std = @import("std");
const alsa = @import("alsa.zig");

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
    try amp_relay_daemon();
}

pub fn amp_relay_daemon() !void {
    const chip_device_path = "/dev/gpiochip0";
    const line_index: u32 = 17; // GPIO 17 on a Raspi4
    const is_line_active_low = true; // The way I'm wiring the relay requires this.
    const amp_timeout_ns: u64 = 5 * std.time.ns_per_min; // Duration after which the amp turns off when not playing music
    const loop_sleep_time_ns: u64 = 1 * std.time.ns_per_s; // Sleep interval between each loop iteration

    // NOTE: Need proper rights to be able to do that
    const chip = c.gpiod_chip_open(chip_device_path) orelse return MyErrors.ChipOpenError;
    defer c.gpiod_chip_close(chip);

    const line_settings = c.gpiod_line_settings_new();
    defer c.gpiod_line_settings_free(line_settings);

    if (c.gpiod_line_settings_set_direction(line_settings, c.GPIOD_LINE_DIRECTION_OUTPUT) < 0) {
        return MyErrors.LineSettingsSetError;
    }

    c.gpiod_line_settings_set_active_low(line_settings, is_line_active_low);

    const line_config = c.gpiod_line_config_new();
    defer c.gpiod_line_config_free(line_config);

    if (c.gpiod_line_config_add_line_settings(line_config, &line_index, 1, line_settings) < 0) {
        return MyErrors.AddLineSettingsError;
    }

    const line_request = c.gpiod_chip_request_lines(chip, null, line_config);
    defer c.gpiod_line_request_release(line_request);

    // Start with the amp off and make sure the GPIO has matching state
    if (c.gpiod_line_request_set_value(line_request, line_index, c.GPIOD_LINE_VALUE_INACTIVE) < 0) {
        return MyErrors.SetValueError;
    }
    var amp_on = false;

    const loop = true;
    var was_music_playing = false;
    var last_music_playing_timestamp: std.time.Instant = undefined;

    while (loop) {
        const is_music_playing_now = try alsa.is_alsa_playing();

        if (is_music_playing_now) {
            last_music_playing_timestamp = try std.time.Instant.now();
        }

        if (!was_music_playing) {
            if (is_music_playing_now) {
                if (c.gpiod_line_request_set_value(line_request, line_index, c.GPIOD_LINE_VALUE_ACTIVE) < 0) {
                    return MyErrors.SetValueError;
                }
                amp_on = true;
            } else {
                // If we haven't been playing music for a while and the amp is still on, turn it off!
                if (amp_on) {
                    const now_timestamp = try std.time.Instant.now();
                    if (now_timestamp.since(last_music_playing_timestamp) > amp_timeout_ns) {
                        if (c.gpiod_line_request_set_value(line_request, line_index, c.GPIOD_LINE_VALUE_INACTIVE) < 0) {
                            return MyErrors.SetValueError;
                        }
                        amp_on = false;
                    }
                }
            }
        }

        std.time.sleep(loop_sleep_time_ns);

        was_music_playing = is_music_playing_now;
    }
}

pub fn print_line_status(chip: *c.gpiod_chip, line_index: u32) !void {
    const line_info = c.gpiod_chip_get_line_info(chip, line_index) orelse return MyErrors.LineInfoError;
    defer c.gpiod_line_info_free(line_info);

    const line_name = c.gpiod_line_info_get_name(line_info);
    std.debug.print("Line: {s}\n", .{line_name});

    const line_direction = c.gpiod_line_info_get_direction(line_info);
    std.debug.print("Direction: {s}\n", .{if (line_direction == c.GPIOD_LINE_DIRECTION_INPUT) "input" else "output"});

    const line_used = c.gpiod_line_info_is_used(line_info);
    std.debug.print("Used: {s}\n", .{if (line_used) "yes" else "no"});
}
