use bufio;
use fmt;
use fs;
use io;
use os;
use strconv;
use strings;

// Hare uses raw leap second informtion when dealing with the UTC and TAI
// timescales. This information is source from a standard file installed at
// /usr/share/zoneinfo/leap-seconds.list, which itself is fetched from and
// periodically maintained at:
//
// <ftp://ftp.nist.gov/pub/time/leap-seconds.list>
// <ftp://ftp.boulder.nist.gov/pub/time/leap-seconds.list>
//
// This is in contrast to legacy systems which rely on TZif files, which are
// installed typically at /usr/share/zoneinfo, as part of the "Olson" IANA
// Timezone databse. These files couple timezone and leap second information
// into one datablock.
//
// Depending on a system's installation, leap second information may be
// deliberately left out of the TZif files, or duplicated throughout. This
// design also inhibits our ambitions for dealing with multiple, dynamic
// timescales. Therefore, we have decided to take an alternative approach.

// The number of seconds between the years 1900 and 1970.
export def SECS_1900_1970: i64 = 2208988800;

// The filepath of the leap-seconds.list file
export def UTC_LEAPSECS_FILE: str = "/usr/share/zoneinfo/leap-seconds.list";

// UTC timestamps and their TAI offsets, sourced from leap-seconds.list
let utc_leapsecs: [](i64, i64) = [];

@init fn init_utc_leapsecs() void = {
	os::init_cwd();
	const file = match (os::open(UTC_LEAPSECS_FILE)) {
	case let file: io::file =>
		yield file;
	case fs::error =>
		return;
	};
	read_leapsecfile(file, &utc_leapsecs)!;
};

fn read_leapsecfile(h: io::handle, leapsecs: *[](i64, i64)) (void | io::error) = {
	let buffer: [os::BUFSIZ]u8 = [0...];
	const b = bufio::buffered(h, buffer, []);
	for (true) {
		const line = match (bufio::scanline(&b)) {
		case let err: io::error =>
			return err;
		case io::EOF =>
			return;
		case let line: []u8 =>
			yield line;
		};
		const line = fmt::bsprint(line);
		if (strings::hasprefix(line, '#')) {
			continue;
		};
		const pair = strings::splitn(line, "\t", 3);
		if (len(pair) < 2) {
			continue;
		};
		const a = strconv::stoi64(pair[0])!;
		const b = strconv::stoi64(pair[1])!;
		const a = a - SECS_1900_1970;
		const pair = (a: i64, b: i64);
		append(utc_leapsecs, pair);
	};
};
