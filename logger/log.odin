package logger

import "core:log"
import "core:fmt"

console_log :: proc(fmt_str: string) {
    // console logger with a minimum log level
    context.logger = log.create_console_logger(lowest = .Debug)

    defer log.destroy_console_logger(context.logger)

    log.info("Program has started!")
    log.warn("This is a warning message.")

    log.errorf(fmt_str)

}