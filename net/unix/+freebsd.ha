// License: MPL-2.0
// (c) 2021 Drew DeVault <sir@cmpwn.com>
// (c) 2021 Eyal Sawady <ecs@d2evs.net>
use errors;
use fmt;
use io;
use net;
use os;
use rt;
use strings;
use types;

// Opens a UNIX socket connection to the path. Blocks until the connection is
// established.
export fn connect(addr: addr) (io::file | net::error) = {
	let sockaddr = match (to_native(addr)) {
	case let a: rt::sockaddr =>
		yield a;
	case invalid =>
		return errors::unsupported; // path too long
	};
	const sockfd = match (rt::socket(rt::AF_UNIX: int, rt::SOCK_STREAM, 0)) {
	case let err: rt::errno =>
		return errors::errno(err);
	case let fd: int =>
		yield fd;
	};
	let flags = rt::fcntl(sockfd, rt::F_GETFL, 0)!;
	rt::fcntl(sockfd, rt::F_SETFL, flags | rt::O_CLOEXEC)!;

	const sz = size(rt::sockaddr_un): u32;
	match (rt::connect(sockfd, &sockaddr, sz)) {
	case let err: rt::errno =>
		return errors::errno(err);
	case int => void;
	};
	static let buf: [rt::UNIX_PATH_MAX + 32]u8 = [0...];
	return io::fdopen(sockfd);
};

// Binds a UNIX socket to the given path.
export fn listen(
	addr: addr,
	options: listen_option...
) (io::file | net::error) = {
	let sockaddr = match (to_native(addr)) {
	case let a: rt::sockaddr =>
		yield a;
	case invalid =>
		return errors::unsupported; // path too long
	};
	const sockfd = match (rt::socket(rt::AF_UNIX: int, rt::SOCK_STREAM, 0)) {
	case let err: rt::errno =>
		return errors::errno(err);
	case let fd: int =>
		yield fd;
	};
	let flags = rt::fcntl(sockfd, rt::F_GETFL, 0)!;
	rt::fcntl(sockfd, rt::F_SETFL, flags | rt::O_CLOEXEC)!;

	let bk: u32 = 10;
	for (let i = 0z; i < len(options); i += 1) {
		// Only option is backlog right now
		bk = options[i];
	};

	match (rt::bind(sockfd, &sockaddr, size(rt::sockaddr_un): u32)) {
	case let err: rt::errno =>
		return errors::errno(err);
	case int => void;
	};
	match (rt::listen(sockfd, bk)) {
	case let err: rt::errno =>
		return errors::errno(err);
	case int => void;
	};

	return sockfd;
};

// Converts a UNIX socket address to a native sockaddr.
fn to_native(addr: addr) (rt::sockaddr | invalid) = {
	// sun_path should be NUL-terminated and fit into rt::UNIX_PATH_MAX
	if (len(addr) > rt::UNIX_PATH_MAX - 1) {
		return invalid;
	};
	let ret = rt::sockaddr {
		un = rt::sockaddr_un {
			sun_len = size(rt::sockaddr_un): u8,
			sun_family = rt::AF_UNIX,
			...
		}
	};
	match ((&addr: *types::string).data) {
	case null => void;
	case let data: *[*]u8 =>
		rt::memcpy(&ret.un.sun_path, data, len(addr));
	};
	ret.un.sun_path[len(addr)] = 0;
	return ret;
};
