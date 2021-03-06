use bufio;
use io;
use os;
use path;
use time;

// The virtual region a moment is interpreted in
export type locality = *timezone;

// A timezone; a political region with a ruleset regarding offsets for
// calculating localized civil time
export type timezone = struct {
	// The textual identifier ("Europe/Amsterdam")
	name: str,

	// The base timescale (chrono::utc)
	timescale: *timescale,

	// The duration of a day in this timezone (24 * time::HOUR)
	daylength: time::duration,

	// The possible temporal zones a locality with this timezone can observe
	// (CET, CEST, ...)
	zones: []zone,

	// The transitions between this timezone's zones
	transitions: []transition,

	// A timezone specifier in the POSIX "expanded" TZ format.
	// See https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap08.html
	//
	// Used for extending calculations beyond the last known transition.
	posix_extend: str,
};

// A timezone state, with an offset for calculating localized civil time
export type zone = struct {
	// The offset from the normal timezone (2 * time::HOUR)
	zoffset: time::duration,

	// The full descriptive name ("Central European Summer Time")
	name: str,

	// The abbreviated name ("CEST")
	abbr: str,

	// Indicator of Daylight Saving Time
	dst: bool, // true
};

// A timezone transition between two zones
export type transition = struct {
	when: time::instant,
	zoneindex: int,
};

// A destructured dual std/dst POSIX timezone. See tzset(3).
type tzname = struct {
	std_name: str,
	std_offset: time::duration,
	dst_name: str,
	dst_offset: time::duration,
	dst_start: str,
	dst_starttime: str,
	dst_end: str,
	dst_endtime: str,
};

// Converts a [[moment]] to one in a different [[locality]]
export fn in(loc: locality, m: moment) moment = {
	assert(m.time < loc.daylength, "Internal error: time excedes daylength");
	return new(m.date, m.time, loc)!; // resets .zone
};

export fn transform(m: moment, zo: time::duration) moment = {
	const daylen = m.loc.daylength;

	const t = m.time + zo;
	const mtime = (if (t >= 0) t else t + daylen) % daylen;

	const d = (t / daylen): int;
	const mdate = m.date + (if (t >= 0) d else d - 1);

	m.time = mtime;
	m.date = mdate;
	return m;
};

// Finds, sets and returns a [[moment]]'s currently observed zone
export fn lookupzone(m: *moment) zone = {
	if (len(m.loc.zones) == 0) {
		// TODO: what to do? not ideal to assume UTC
		abort("lookup(): timezones should have at least one zone");
	};

	if (len(m.loc.zones) == 1) {
		m.zone = m.loc.zones[0];
		return m.zone;
	};

	const inst = to_instant(*m);

	if (
		len(m.loc.transitions) == 0
		|| time::compare(inst, m.loc.transitions[0].when) == -1
	) {
		// TODO: special case
		abort("lookupzone(): time is before known transitions");
	};

	let lo = 0z;
	let hi = len(m.loc.transitions);
	for (hi - lo > 1) {
		const mid = lo + (hi - lo) / 2;
		const middle = m.loc.transitions[mid].when;
		switch (time::compare(inst, middle)) {
		case -1 =>
			hi = mid;
		case 0 =>
			lo = mid; break;
		case 1 =>
			lo = mid;
		case =>
			abort("Unreachable");
		};
	};

	m.zone = m.loc.zones[m.loc.transitions[lo].zoneindex];

	// if we've reached the end of the locality's transitions, try its
	// posix_extend string
	//
	// TODO: Unfinished; complete.
	if (lo == len(m.loc.transitions) - 1 && m.loc.posix_extend != "") {
		void;
	};

	return m.zone;
};

// Creates a [[timezone]] with a single [[zone]]. Useful for fixed offsets.
// For example, replicate the civil time Hawaii timezone on Earth:
//
// 	let hawaii = chrono::fixedzone(&chrono::utc, chrono::EARTH_DAY,
// 		chrono::zone {
// 			zoffset = -10 * time::HOUR,
// 			name = "Hawaiian Reef",
// 			abbr = "HARE",
// 			dst = false,
// 		},
// 	);
//
export fn fixedzone(ts: *timescale, daylen: time::duration, z: zone) timezone = {
	return timezone {
		name = z.name,
		timescale = ts,
		daylength = daylen,
		zones = alloc([z]),
		transitions = [],
		posix_extend = "",
	};
};

// The system's local timezone, set during initialisation
export const LOCAL: locality = &TZ_local;

@init fn set_local_timezone() void = {
	match (os::getenv("TZ")) {
	case let zone: str =>
		TZ_local = match (tz(zone)) {
		case let tz: timezone =>
			yield tz;
		case =>
			return;
		};
	case void =>
		const file = match (os::open(LOCALTIME_PATH)) {
		case let file: io::file =>
			yield file;
		case =>
			return;
		};
		defer io::close(file)!;

		static let buf: [os::BUFSIZ]u8 = [0...];
		const file = bufio::buffered(file, buf, []);
		TZ_local = match (parse_tzif(&file, timezone {
			name = "Local time",
			timescale = &utc,
			daylength = EARTH_DAY,
			...
		})) {
		case let tz: timezone =>
			yield tz;
		case =>
			return;
		};
	};
};

let TZ_local: timezone = timezone {
	name = "Local time",
	timescale = &utc,
	daylength = EARTH_DAY,
	zones = [
		zone {
			zoffset = 0 * time::SECOND,
			name = "Local time",
			abbr = "",
			dst = false,
		},
	],
	transitions = [],
	posix_extend = "",
};

// The UTC (Coordinated Universal Time) "Zulu" timezone
export const UTC: locality = &TZ_UTC;

const TZ_UTC: timezone = timezone {
	name = "UTC",
	timescale = &utc,
	daylength = EARTH_DAY,
	zones = [
		zone {
			zoffset = 0 * time::SECOND,
			name = "Universal Coordinated Time",
			abbr = "UTC",
			dst = false,
		},
	],
	transitions = [],
	posix_extend = "",
};

// The TAI (International Atomic Time) "Zulu" timezone
export const TAI: locality = &TZ_TAI;

const TZ_TAI: timezone = timezone {
	name = "",
	timescale = &tai,
	daylength = EARTH_DAY,
	zones = [
		zone {
			zoffset = 0 * time::SECOND,
			name = "International Atomic Time",
			abbr = "TAI",
			dst = false,
		},
	],
	transitions = [],
	posix_extend = "",
};

// The MTC (Coordinated Mars Time) "Zulu" timezone
export const MTC: locality = &TZ_MTC;

const TZ_MTC: timezone = timezone {
	name = "",
	timescale = &mtc,
	daylength = MARS_SOL_MARTIAN,
	zones = [
		zone {
			zoffset = 0 * time::SECOND,
			name = "Coordinated Mars Time",
			abbr = "MTC",
			dst = false,
		},
	],
	transitions = [],
	posix_extend = "",
};
