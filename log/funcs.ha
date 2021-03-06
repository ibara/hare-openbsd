use fmt;
use os;

// Prints data to the log, with a newline.
export fn lprintln(log: *logger, fields: fmt::formattable...) void = {
	log.println(log, fields...);
};

// Formats and prints data to the log, with a newline.
export fn lprintfln(log: *logger, fmt: str, fields: fmt::field...) void = {
	log.printfln(log, fmt, fields...);
};

// Prints data to the global log, with a newline
export fn println(fields: fmt::formattable...) void = {
	lprintln(global, fields...);
};

// Formats and prints data to the global log, with a newline.
export fn printfln(fmt: str, fields: fmt::field...) void = {
	lprintfln(global, fmt, fields...);
};

// Formats and prints data to the log, then terminates the process.
export @noreturn fn lfatal(
	log: *logger,
	fmt: str,
	fields: fmt::field...
) void = {
	lprintfln(global, fmt, fields...);
	os::exit(1);
};

// Formats and prints data to the global log, then terminates the process.
export @noreturn fn fatal(fmt: str, fields: fmt::field...) void = {
	lprintfln(global, fmt, fields...);
	os::exit(1);
};
