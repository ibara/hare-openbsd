// License: MPL-2.0
// (c) 2021 Drew DeVault <sir@cmpwn.com>

// Configures the backlog size for a listener. If not specified, a sensible
// default (10) is used.
export type backlog = u32;

// Options for [[listen]].
export type listen_option = backlog;
