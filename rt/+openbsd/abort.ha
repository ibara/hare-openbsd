// License: MPL-2.0
// (c) 2021 Drew DeVault <sir@cmpwn.com>

fn platform_abort(msg: str) void = {
	const prefix = "Abort: ";
	const linefeed = "\n";
	write(2, *(&prefix: **void): *const char, len(prefix)): void;
	write(2, *(&msg: **void): *const char, len(msg)): void;
	write(2, *(&linefeed: **void): *const char, 1): void;
	kill(getpid(), SIGABRT): void;
	for (true) void;
};
