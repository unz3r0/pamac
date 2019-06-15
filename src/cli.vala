/*
 *  pamac-vala
 *
 *  Copyright (C) 2019 Guillaume Benoit <guillaume@manjaro.org>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a get of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
MainLoop loop;

namespace Pamac {
	class Cli: Object {
		public int exit_status;
		public TransactionCli transaction;
		Database database;
		delegate void TransactionAction ();
		string[] to_install;
		string[] to_remove;
		string[] to_load;
		string[] to_build;
		bool force_refresh;
		bool trans_cancellable;
		bool waiting;
		string[] temporary_ignorepkgs;
		string[] overwrite_files;
		GenericSet<string?> already_checked_aur_dep;
		public Subprocess pkttyagent;

		public Cli () {
			exit_status = 0;
			to_install = {};
			to_remove = {};
			to_load = {};
			to_build = {};
			force_refresh = false;
			trans_cancellable = false;
			waiting = false;
			overwrite_files = {};
			// watch CTRl + C
			Unix.signal_add (Posix.Signal.INT, trans_cancel);
		}

		public void parse_command_line (string[] args) {
			if (args.length == 1) {
				display_help ();
				return;
			}
			if (args[1] == "--help" || args[1] == "-h") {
				if (args.length > 2) {
					if (args[2] == "search") {
						display_search_help ();
					} else if (args[2] == "info") {
						display_info_help ();
					} else if (args[2] == "list") {
						display_list_help ();
					} else if (args[2] == "build") {
						display_build_help ();
					} else if (args[2] == "install") {
						display_install_help ();
					} else if (args[2] == "reinstall") {
						display_reinstall_help ();
					} else if (args[2] == "remove") {
						display_remove_help ();
					} else if (args[2] == "checkupdates") {
						display_checkupdates_help ();
					} else if (args[2] == "upgrade" || args[2] == "update") {
						display_upgrade_help ();
					} else if (args[2] == "clean") {
						display_clean_help ();
					} else {
						display_help ();
					}
				} else {
					display_help ();
				}
			} else if (args[1] == "--version") {
				display_version ();
			} else if (args[1] == "search") {
				if (args.length > 2) {
					if (args[2] == "--help" || args[2] == "-h") {
						display_search_help ();
					} else if (args[2] == "--aur" || args[2] == "-a") {
						init_database ();
						database.config.enable_aur = true;
						search_pkgs.begin (concatenate_strings (args[3:args.length]), () => {
							loop.quit ();
						});
						loop.run ();
					} else if (args[2] == "--files" || args[2] == "-f") {
						init_database ();
						search_files (args[3:args.length]);
					} else {
						init_database ();
						search_pkgs.begin (concatenate_strings (args[2:args.length]), () => {
							loop.quit ();
						});
						loop.run ();
					}
				} else {
					display_search_help ();
				}
			} else if (args[1] == "info") {
				if (args.length > 2) {
					if (args[2] == "--help" || args[2] == "-h") {
						display_info_help ();
					} else if (args[2] == "--aur" || args[2] == "-a") {
						init_database ();
						database.config.enable_aur = true;
						display_pkg_infos.begin (args[3:args.length], () => {
							loop.quit ();
						});
						loop.run ();
					} else {
						init_database ();
						// enable aur to display more info for installed pkgs from AUR
						database.config.enable_aur = true;
						display_pkg_infos.begin (args[2:args.length], () => {
							loop.quit ();
						});
						loop.run ();
					}
				} else {
					display_info_help ();
				}
			} else if (args[1] == "list") {
				if (args.length > 2) {
					if (args[2] == "--help" || args[2] == "-h") {
						display_list_help ();
					} else if (args[2] == "--installed" || args[2] == "-i") {
						init_database ();
						list_installed ();
					} else if (args[2] == "--orphans" || args[2] == "-o") {
						init_database ();
						list_orphans ();
					} else if (args[2] == "--foreign" || args[2] == "-m") {
						init_database ();
						list_foreign ();
					} else if (args[2] == "--groups" || args[2] == "-g") {
						init_database ();
						if (args.length > 3) {
							list_groups (args[3:args.length]);
						} else {
							list_groups ({});
						}
					} else if (args[2] == "--repos" || args[2] == "-r") {
						init_database ();
						if (args.length > 3) {
							list_repos (args[3:args.length]);
						} else {
							list_repos ({});
						}
					} else if (args[2] == "--files" || args[2] == "-f") {
						if (args.length > 3) {
							init_database ();
							list_files (args[3:args.length]);
						} else {
							display_list_help ();
						}
					} else {
						display_list_help ();
					}
				} else {
					init_database ();
					list_installed ();
				}
			} else if (args[1] == "clone") {
				if (args.length > 2) {
					if (args[2] == "--help" || args[2] == "-h") {
						display_clone_help ();
					} else {
						init_database ();
						database.config.enable_aur = true;
						string[] targets = {};
						bool overwrite = false;
						bool recurse = false;
						int i = 2;
						while (i < args.length) {
							unowned string arg = args[i];
							if (arg == "--overwrite") {
								overwrite = true;
							} else if (arg == "--recurse" || arg == "-r") {
								recurse = true;
							} else if (arg == "--builddir") {
								if (args[i + 1] != null) {
									database.config.aur_build_dir = args[i + 1];
								}
								i++;
							} else {
								targets += arg;
							}
							i++;
						}
						clone_build_files (targets, overwrite, recurse);
					}
				} else {
					display_clone_help ();
				}
			} else if (args[1] == "build") {
				if (Posix.geteuid () == 0) {
					// can't build as root
					stdout.printf (dgettext (null, "Building packages as root is not allowed") + "\n");
					exit_status = 1;
					return;
				}
				if (args.length > 2) {
					if (args[2] == "--help" || args[2] == "-h") {
						display_build_help ();
						return;
					}
				}
				init_transaction ();
				database.config.enable_aur = true;
				string[] targets = {};
				int i = 2;
				while (i < args.length) {
					unowned string arg = args[i];
					if (arg == "--no-clone") {
						transaction.clone_build_files = false;
					} else if (arg == "--builddir") {
						if (args[i + 1] != null) {
							database.config.aur_build_dir = args[i + 1];
						}
						i++;
					} else if (arg == "--no-confirm") {
						transaction.no_confirm = true;
					} else {
						targets += arg;
					}
					i++;
				}
				if (targets.length == 0) {
					var current_dir = File.new_for_path (Environment.get_current_dir ());
					var pkgbuild = current_dir.get_child ("PKGBUILD");
					if (!pkgbuild.query_exists ()) {
						stdout.printf (dgettext (null, "No PKGBUILD file found in current directory"));
						stdout.printf ("\n");
						return;
					}
					// set buildir to the parent dir
					File? parent = current_dir.get_parent ();
					if (parent != null) {
						database.config.aur_build_dir = parent.get_path ();
					}
					string? pkgbase = current_dir.get_basename ();
					if (pkgbase != null) {
						// add pkgnames of srcinfo to targets
						var cancellable = new Cancellable ();
						database.regenerate_srcinfo.begin (pkgbase, cancellable, (obj, res) => {
							bool success = database.regenerate_srcinfo.end (res);
							if (success) {
								foreach (unowned string pkgname in database.get_srcinfo_pkgnames (pkgbase)) {
									targets += pkgname;
								}
							}
							loop.quit ();
						});
						loop.run ();
					}
				} else if (transaction.clone_build_files) {
					// check if targets exist
					bool success = true;
					check_build_pkgs.begin (targets, (obj, res) => {
						success = check_build_pkgs.end (res);
						loop.quit ();
					});
					loop.run ();
					if (!success) {
						return;
					}
				}
				build_pkgs (targets);
			} else if (args[1] == "install") {
				if (args.length > 2) {
					if (args[2] == "--help" || args[2] == "-h") {
						display_install_help ();
					} else {
						init_transaction ();
						string[] targets = {};
						int i = 2;
						while (i < args.length) {
							unowned string arg = args[i];
							if (arg == "--overwrite") {
								foreach (unowned string name in args[i + 1].split(",")) {
									overwrite_files += name;
								}
								i++;
							} else if (arg == "--ignore") {
								foreach (unowned string name in args[i + 1].split(",")) {
									temporary_ignorepkgs += name;
								}
								i++;
							} else if (arg == "--no-confirm") {
								transaction.no_confirm = true;
							} else {
								targets += arg;
							}
							i++;
						}
						install_pkgs (targets);
					}
				} else {
					display_install_help ();
				}
			} else if (args[1] == "reinstall") {
				if (args.length > 2) {
					if (args[2] == "--help" || args[2] == "-h") {
						display_reinstall_help ();
					} else {
						init_transaction ();
						string[] targets = {};
						int i = 2;
						while (i < args.length) {
							unowned string arg = args[i];
							if (arg == "--overwrite") {
								foreach (unowned string name in args[i + 1].split(",")) {
									overwrite_files += name;
								}
								i++;
							} else if (arg == "--no-confirm") {
								transaction.no_confirm = true;
							} else {
								targets += arg;
							}
							i++;
						}
						reinstall_pkgs (targets);
					}
				} else {
					display_reinstall_help ();
				}
			} else if (args[1] == "remove") {
				if (args.length > 2) {
					if (args[2] == "--help" || args[2] == "-h") {
						display_remove_help ();
					} else {
						init_transaction ();
						bool recurse = false;
						string[] targets = {};
						int i = 2;
						while (i < args.length) {
							unowned string arg = args[i];
							if (arg == "--orphans" || arg == "-o") {
								recurse = true;
							} else if (arg == "--no-confirm") {
								transaction.no_confirm = true;
							} else {
								targets += arg;
							}
							i++;
						}
						if (targets.length > 0) {
							remove_pkgs (targets, recurse);
						} else if (recurse) {
							remove_orphans ();
						}
					}
				} else {
					display_remove_help ();
				}
			} else if (args[1] == "checkupdates") {
				init_database ();
				bool error = false;
				bool quiet = false;
				bool refresh_tmp_files_dbs = false;
				bool download_updates = false;
				int i = 2;
				while (i < args.length) {
					unowned string arg = args[i];
					if (arg == "--help" || arg == "-h") {
						display_checkupdates_help ();
						error = true;
						break;
					} else if (arg == "--quiet" || arg == "-q") {
						quiet = true;
					} else if (arg == "--refresh-tmp-files-dbs") {
						refresh_tmp_files_dbs = true;
					} else if (arg == "--download-updates") {
						download_updates = true;
					} else if (arg == "--aur" || arg == "-a") {
						database.config.enable_aur = true;
						database.config.check_aur_updates = true;
					} else if (arg == "-aq" || arg == "-qa") {
						database.config.enable_aur = true;
						database.config.check_aur_updates = true;
						quiet = true;
					} else if (arg == "--builddir") {
						if (args[i + 1] != null) {
							database.config.aur_build_dir = args[i + 1];
						}
						i++;
					} else if (arg == "--devel") {
						if (Posix.geteuid () == 0) {
							// can't check as root
							stdout.printf (dgettext (null, "Check development packages updates as root is not allowed") + "\n");
							exit_status = 1;
							return;
						}
						database.config.check_aur_vcs_updates = true;
					} else {
						display_checkupdates_help ();
						error = true;
						break;
					}
					i++;
				}
				if (!error) {
					checkupdates.begin (quiet, refresh_tmp_files_dbs, download_updates, () => {
						loop.quit ();
					});
					loop.run ();
				}
			} else if (args[1] == "update" || args[1] == "upgrade") {
				init_transaction ();
				bool error = false;
				int i = 2;
				while (i < args.length) {
					unowned string arg = args[i];
					if (arg == "--help" || arg == "-h") {
						display_upgrade_help ();
						error = true;
						break;
					} else if (arg == "--aur"|| arg == "-a") {
						if (Posix.geteuid () == 0) {
							// can't build as root
							stdout.printf (dgettext (null, "Building packages as root is not allowed") + "\n");
							exit_status = 1;
							return;
						}
						database.config.enable_aur = true;
						database.config.check_aur_updates = true;
					} else if (arg == "--builddir") {
						if (args[i + 1] != null) {
							database.config.aur_build_dir = args[i + 1];
						}
						i++;
					} else if (arg == "--force-refresh") {
						force_refresh = true;
					} else if (arg == "--enable-downgrade") {
						database.config.enable_downgrade = true;
					} else if (arg == "--ignore") {
						foreach (unowned string name in args[i + 1].split(",")) {
							temporary_ignorepkgs += name;
						}
						i++;
					} else if (arg == "--overwrite") {
						foreach (unowned string name in args[i + 1].split(",")) {
							overwrite_files += name;
						}
						i++;
					} else if (arg == "--no-confirm") {
						transaction.no_confirm = true;
					} else {
						display_upgrade_help ();
						error = true;
						break;
					}
					i++;
				}
				if (!error) {
					try_lock_and_run (start_sysupgrade);
				}
			} else if (args[1] == "clean") {
				init_transaction ();
				bool error = false;
				bool verbose = false;
				bool build_files = false;
				bool dry_run = false;
				bool no_confirm = false;
				int i = 2;
				while (i < args.length) {
					unowned string arg = args[i];
					if (arg == "--help" || arg == "-h") {
						display_clean_help ();
						error = true;
						break;
					} else if (arg == "--build-files" || arg == "-b") {
						build_files = true;
					} else if (arg == "--no-confirm") {
						no_confirm = true;
					} else if (arg == "--keep" || arg == "-k") {
						if (args[i + 1] != null) {
							int64 num;
							if (int64.try_parse (args[i + 1], out num)) {
								database.config.clean_keep_num_pkgs = num;
							} else {
								display_clean_help ();
								error = true;
								break;
							}
						} else {
							display_clean_help ();
							error = true;
							break;
						}
						i++;
					} else if (arg.has_prefix ("-k")) {
						string number = arg.split ("-k", 2)[1];
						if (number.has_prefix ("=")) {
							number = number.split ("=", 2)[1];
							if (number == "") {
								display_clean_help ();
								error = true;
								break;
							}
						}
						int64 num;
						if (int64.try_parse (number, out num)) {
							database.config.clean_keep_num_pkgs = num;
						} else {
							display_clean_help ();
							error = true;
							break;
						}
					} else if (arg == "--uninstalled" || arg == "-u") {
						database.config.clean_rm_only_uninstalled = true;
					} else if (arg == "--dry-run" || arg == "-d") {
						dry_run = true;
					} else if (arg == "--verbose" || arg == "-v") {
						verbose = true;
					} else if (arg == "-bv" || arg == "-vb") {
						build_files = true;
						verbose = true;
					} else if (arg == "-dv" || arg == "-vd") {
						dry_run = true;
						verbose = true;
					} else if (arg == "-bd" || arg == "-db") {
						dry_run = true;
						build_files = true;
					} else if (arg == "-du" || arg == "-ud") {
						dry_run = true;
						database.config.clean_rm_only_uninstalled = true;
					} else if (arg == "-uv" || arg == "-vu") {
						verbose = true;
						database.config.clean_rm_only_uninstalled = true;
					} else if (arg == "-bdv" || arg == "-bvd"
							|| arg == "-dbv" || arg == "-dvb"
							|| arg == "-vbd" || arg == "-vdb") {
						build_files = true;
						dry_run = true;
						verbose = true;
					} else if (arg == "-udv" || arg == "-uvd"
							|| arg == "-duv" || arg == "-dvu"
							|| arg == "-vud" || arg == "-vdu") {
						database.config.clean_rm_only_uninstalled = true;
						dry_run = true;
						verbose = true;
					} else {
						display_clean_help ();
						error = true;
						break;
					}
					i++;
				}
				if (!error) {
					if (build_files) {
						clean_build_files (dry_run, verbose, no_confirm);
					} else {
						clean_cache (dry_run, verbose, no_confirm);
					}
				}
			} else {
				display_help ();
			}
		}

		void init_database () {
			var config = new Config ("/etc/pamac.conf");
			database = new Database (config);
		}

		void init_transaction () {
			if (database == null) {
				init_database ();
			}
			transaction = new TransactionCli (database);
			transaction.finished.connect (on_transaction_finished);
			transaction.sysupgrade_finished.connect (on_transaction_finished);
			transaction.start_downloading.connect (() => {
				trans_cancellable = true;
			});
			transaction.stop_downloading.connect (() => {
				trans_cancellable = false;
			});
			transaction.start_building.connect (() => {
				trans_cancellable = true;
			});
			transaction.stop_building.connect (() => {
				trans_cancellable = false;
			});
			if (Posix.geteuid () != 0) {
				// Use tty polkit authentication agent
				try {
					pkttyagent = new Subprocess.newv ({"pkttyagent"}, SubprocessFlags.NONE);
				} catch (Error e) {
					stdout.printf ("%s: %s\n", dgettext (null, "Error"), e.message);
				}
			}
		}

		bool trans_cancel () {
			if (waiting) {
				waiting = false;
				stdout.printf ("\n");
				loop.quit ();
			} else if (trans_cancellable) {
				transaction.cancel ();
			} else {
				stdout.printf ("\n");
			}
			return true;
		}

		int get_term_width () {
			int width = 80;
			Linux.winsize win;
			if (Linux.ioctl (Posix.STDOUT_FILENO, Linux.Termios.TIOCGWINSZ, out win) == 0) {
				width = win.ws_col;
			}
			return width;
		}

		string concatenate_strings_list (List<string> list) {
			var str_builder = new StringBuilder ();
			foreach (unowned string str in list) {
				if (str_builder.len > 0) {
					str_builder.append (" ");
				}
				str_builder.append (str);
			}
			return str_builder.str;
		}

		string concatenate_strings (string[] list) {
			var str_builder = new StringBuilder ();
			foreach (unowned string str in list) {
				if (str_builder.len > 0) {
					str_builder.append (" ");
				}
				str_builder.append (str);
			}
			return str_builder.str;
		}

		string[] split_string (string str, int margin, int width = 0) {
			int term_width = get_term_width ();
			if (width == 0) {
				width = term_width;
			}
			if (width > term_width) {
				width = term_width;
			}
			int str_length = str.length;
			int available_width = width - margin;
			if (available_width >= str_length) {
				return {str};
			}
			int remain_length = str_length;
			int offset = 0;
			string[] splitted = {};
			while (remain_length >= available_width) {
				string remain_string = str.substring (offset, remain_length);
				string cutted_string = remain_string.substring (0, available_width);
				int cut_length = available_width;
				// cut at word
				int i = cutted_string.last_index_of_char (' ');
				if (i != -1) {
					cut_length = i;
					cutted_string = remain_string.substring (0, i);
				}
				splitted += cutted_string;
				offset += cut_length + 1;
				remain_length -= cut_length + 1;
			}
			if (remain_length > 0) {
				splitted += str.substring (offset, remain_length);
			}
			return splitted;
		}

		void print_aligned (string str1, string str2, int width) {
			var str_builder = new StringBuilder ();
			str_builder.append (str1);
			int diff = width - str1.char_count ();
			if (diff > 0) {
				while (diff > 0) {
					str_builder.append (" ");
					diff--;
				}
			}
			str_builder.append (str2);
			stdout.printf ("%s\n", str_builder.str);
		}

		void print_error (string message) {
			stdout.printf ("%s: %s\n", dgettext (null, "Error"), message);
			exit_status = 1;
		}

		void display_version () {
			stdout.printf ("Pamac  %s\n", VERSION);
		}

		void display_help () {
			string[] actions = {"--version",
								"--help,-h",
								"clean",
								"checkupdates",
								"update,upgrade",
								"search",
								"info",
								"list",
								"install",
								"reinstall",
								"clone",
								"build",
								"remove"};
			string[] options_actions = {"clean",
										"checkupdates",
										"update,upgrade",
										"search",
										"info",
										"list",
										"install",
										"reinstall",
										"build",
										"clone",
										"remove"};
			string[] targets_actions = {"search",
										"info",
										"list",
										"install",
										"reinstall",
										"build",
										"clone",
										"remove"};
			stdout.printf (dgettext (null, "Available actions") + ":\n");
			foreach (unowned string action in actions) {
				stdout.printf ("  pamac %-14s".printf (action));
				if (action == "--help,-h") {
					stdout.printf (" [%s]".printf (dgettext (null,  "action")));
				}
				if (action in options_actions) {
					stdout.printf (" [%s]".printf (dgettext (null,  "options")));
				}
				if (action in targets_actions) {
					if (action == "remove" || action == "build") {
						stdout.printf (" [%s]".printf (dgettext (null,  "package(s)")));
					} else {
						stdout.printf (" <%s>".printf (dgettext (null,  "package(s)")));
					}
				}
				stdout.printf ("\n");
			}
		}

		void display_search_help () {
			stdout.printf (dgettext (null, "Search for packages or files, multiple search terms can be specified"));
			stdout.printf ("\n\n");
			stdout.printf ("pamac search [%s] <%s>".printf (dgettext (null, "options"), "%s,%s".printf (dgettext (null, "package(s)"), dgettext (null, "file(s)"))));
			stdout.printf ("\n\n");
			stdout.printf (dgettext (null, "options") + ":\n");
			int max_length = 0;
			string[] options = {"  -a, --aur",
								"  -f, --files"};
			foreach (unowned string option in options) {
				int length = option.char_count ();
				if (length > max_length) {
					max_length = length;
				}
			}
			string[] details = {dgettext (null, "also search in AUR"),
								dgettext (null, "search for packages which own the given filenames (filenames can be partial)")};
			int i = 0;
			foreach (unowned string option in options) {
				string[] cuts = split_string (details[i], max_length + 3);
				print_aligned (option, " : %s".printf (cuts[0]), max_length);
				int j = 1;
				while (j < cuts.length) {
					print_aligned ("", "%s".printf (cuts[j]), max_length + 3);
					j++;
				}
				i++;
			}
		}

		void display_info_help () {
			stdout.printf (dgettext (null, "Display package details, multiple packages can be specified"));
			stdout.printf ("\n\n");
			stdout.printf ("pamac info [%s] <%s>".printf (dgettext (null, "options"), dgettext (null, "package(s)")));
			stdout.printf ("\n\n");
			stdout.printf (dgettext (null, "options") + ":\n");
			int max_length = 0;
			string[] options = {"  -a, --aur"};
			foreach (unowned string option in options) {
				int length = option.char_count ();
				if (length > max_length) {
					max_length = length;
				}
			}
			string[] details = {dgettext (null, "also search in AUR")};
			int i = 0;
			foreach (unowned string option in options) {
				string[] cuts = split_string (details[i], max_length + 3);
				print_aligned (option, " : %s".printf (cuts[0]), max_length);
				int j = 1;
				while (j < cuts.length) {
					print_aligned ("", "%s".printf (cuts[j]), max_length + 3);
					j++;
				}
				i++;
			}
		}

		void display_list_help () {
			stdout.printf (dgettext (null, "List packages, groups, repositories or files"));
			stdout.printf ("\n\n");
			stdout.printf ("pamac list [%s]".printf (dgettext (null, "options")));
			stdout.printf ("\n\n");
			stdout.printf (dgettext (null, "options") + ":\n");
			int max_length = 0;
			string[] options = {"  -i, --installed",
								"  -o, --orphans",
								"  -m, --foreign",
								"  %s [%s]".printf ("-g, --groups", dgettext (null, "group(s)")),
								"  %s [%s]".printf ("-r, --repos", dgettext (null, "repo(s)")),
								"  %s <%s>".printf ("-f, --files", dgettext (null, "package(s)"))};
			foreach (unowned string option in options) {
				int length = option.char_count ();
				if (length > max_length) {
					max_length = length;
				}
			}
			string[] details = {dgettext (null, "list installed packages"),
								dgettext (null, "list packages that were installed as dependencies but are no longer required by any installed package"),
								dgettext (null, "list packages that were not found in the repositories"),
								dgettext (null, "list all packages that are members of the given groups, if no group is given list all groups"),
								dgettext (null, "list all packages available in the given repos, if no repo is given list all repos"),
								dgettext (null, "list files owned by the given packages")};
			int i = 0;
			foreach (unowned string option in options) {
				string[] cuts = split_string (details[i], max_length + 3);
				print_aligned (option, " : %s".printf (cuts[0]), max_length);
				int j = 1;
				while (j < cuts.length) {
					print_aligned ("", "%s".printf (cuts[j]), max_length + 3);
					j++;
				}
				i++;
			}
		}

		void display_clone_help () {
			stdout.printf (dgettext (null, "Clone or sync packages build files from AUR"));
			stdout.printf ("\n\n");
			stdout.printf ("pamac clone [%s] <%s>".printf (dgettext (null, "options"), dgettext (null, "package(s)")));
			stdout.printf ("\n\n");
			stdout.printf (dgettext (null, "options") + ":\n");
			int max_length = 0;
			string[] options = {"  %s <%s>".printf ("--builddir", dgettext (null, "dir")),
								"  -r,--recurse",
								"  --overwrite"};
			foreach (unowned string option in options) {
				int length = option.char_count ();
				if (length > max_length) {
					max_length = length;
				}
			}
			string[] details = {dgettext (null, "build directory, if no directory is given the one specified in pamac.conf file is used"),
								dgettext (null, "also clone needed dependencies"),
								dgettext (null, "overwrite existing files")};
			int i = 0;
			foreach (unowned string option in options) {
				string[] cuts = split_string (details[i], max_length + 3);
				print_aligned (option, " : %s".printf (cuts[0]), max_length);
				int j = 1;
				while (j < cuts.length) {
					print_aligned ("", "%s".printf (cuts[j]), max_length + 3);
					j++;
				}
				i++;
			}
		}

		void display_build_help () {
			stdout.printf (dgettext (null, "Build packages from AUR and install them with their dependencies"));
			stdout.printf ("\n\n");
			stdout.printf (dgettext (null, "If no package name is given, use the PKGBUILD file in the current directory"));
			stdout.printf ("\n");
			stdout.printf (dgettext (null, "The build directory will be the parent directory, --builddir option will be ignored"));
			stdout.printf ("\n\n");
			stdout.printf ("pamac build [%s] [%s]".printf (dgettext (null, "options"), dgettext (null, "package(s)")));
			stdout.printf ("\n\n");
			stdout.printf (dgettext (null, "options") + ":\n");
			int max_length = 0;
			string[] options = {"  %s <%s>".printf ("--builddir", dgettext (null, "dir")),
								"  --no-clone",
								"  --no-confirm"};
			foreach (unowned string option in options) {
				int length = option.char_count ();
				if (length > max_length) {
					max_length = length;
				}
			}
			string[] details = {dgettext (null, "build directory, if no directory is given the one specified in pamac.conf file is used"),
								dgettext (null, "do not clone build files from AUR, only use local files"),
								dgettext (null, "bypass any and all confirmation messages")};
			int i = 0;
			foreach (unowned string option in options) {
				string[] cuts = split_string (details[i], max_length + 3);
				print_aligned (option, " : %s".printf (cuts[0]), max_length);
				int j = 1;
				while (j < cuts.length) {
					print_aligned ("", "%s".printf (cuts[j]), max_length + 3);
					j++;
				}
				i++;
			}
		}

		void display_install_help () {
			stdout.printf (dgettext (null, "Install packages from repositories, path or url"));
			stdout.printf ("\n\n");
			stdout.printf ("pamac install [%s] <%s>".printf (dgettext (null, "options"), "%s,%s".printf (dgettext (null, "package(s)"), dgettext (null, "group(s)"))));
			stdout.printf ("\n\n");
			stdout.printf (dgettext (null, "options") + ":\n");
			int max_length = 0;
			string[] options = {"  %s <%s>".printf ("--ignore", dgettext (null, "package(s)")),
								"  %s <%s>".printf ("--overwrite", dgettext (null, "glob")),
								"  --no-confirm"};
			foreach (unowned string option in options) {
				int length = option.char_count ();
				if (length > max_length) {
					max_length = length;
				}
			}
			string[] details = {dgettext (null, "ignore a package upgrade, multiple packages can be specified by separating them with a comma"),
								dgettext (null, "overwrite conflicting files, multiple patterns can be specified by separating them with a comma"),
								dgettext (null, "bypass any and all confirmation messages")};
			int i = 0;
			foreach (unowned string option in options) {
				string[] cuts = split_string (details[i], max_length + 3);
				print_aligned (option, " : %s".printf (cuts[0]), max_length);
				int j = 1;
				while (j < cuts.length) {
					print_aligned ("", "%s".printf (cuts[j]), max_length + 3);
					j++;
				}
				i++;
			}
		}

		void display_reinstall_help () {
			stdout.printf (dgettext (null, "Reinstall packages"));
			stdout.printf ("\n\n");
			stdout.printf ("pamac reinstall <%s>".printf ("%s,%s".printf (dgettext (null, "package(s)"), dgettext (null, "group(s)"))));
			stdout.printf ("\n\n");
			stdout.printf (dgettext (null, "options") + ":\n");
			int max_length = 0;
			string[] options = {"  %s <%s>".printf ("--overwrite", dgettext (null, "glob")),
								"  --no-confirm"};
			foreach (unowned string option in options) {
				int length = option.char_count ();
				if (length > max_length) {
					max_length = length;
				}
			}
			string[] details = {dgettext (null, "overwrite conflicting files, multiple patterns can be specified by separating them with a comma"),
								dgettext (null, "bypass any and all confirmation messages")};
			int i = 0;
			foreach (unowned string option in options) {
				string[] cuts = split_string (details[i], max_length + 3);
				print_aligned (option, " : %s".printf (cuts[0]), max_length);
				int j = 1;
				while (j < cuts.length) {
					print_aligned ("", "%s".printf (cuts[j]), max_length + 3);
					j++;
				}
				i++;
			}
		}

		void display_remove_help () {
			stdout.printf (dgettext (null, "Remove packages"));
			stdout.printf ("\n\n");
			stdout.printf ("pamac remove [%s] [%s]".printf (dgettext (null, "options"), "%s,%s".printf (dgettext (null, "package(s)"), dgettext (null, "group(s)"))));
			stdout.printf ("\n\n");
			stdout.printf (dgettext (null, "options") + ":\n");
			int max_length = 0;
			string[] options = {"  -o, --orphans",
								"  --no-confirm"};
			foreach (unowned string option in options) {
				int length = option.char_count ();
				if (length > max_length) {
					max_length = length;
				}
			}
			string[] details = {dgettext (null, "remove dependencies that are not required by other packages, if this option is used without package name remove all orphans"),
								dgettext (null, "bypass any and all confirmation messages")};
			int i = 0;
			foreach (unowned string option in options) {
				string[] cuts = split_string (details[i], max_length + 3);
				print_aligned (option, " : %s".printf (cuts[0]), max_length);
				int j = 1;
				while (j < cuts.length) {
					print_aligned ("", "%s".printf (cuts[j]), max_length + 3);
					j++;
				}
				i++;
			}
		}

		void display_checkupdates_help () {
			stdout.printf (dgettext (null, "Safely check for updates without modifiying the databases"));
			stdout.printf ("\n");
			stdout.printf ("(%s)".printf (dgettext (null, "Exit code is 100 if updates are available")));
			stdout.printf ("\n\n");
			stdout.printf ("pamac checkupdates [%s]".printf (dgettext (null, "options")));
			stdout.printf ("\n\n");
			stdout.printf (dgettext (null, "options") + ":\n");
			int max_length = 0;
			string[] options = {"  -a, --aur",
								"  --devel",
								"  -q, --quiet",
								"  %s <%s>".printf ("--builddir", dgettext (null, "dir"))};
			foreach (unowned string option in options) {
				int length = option.char_count ();
				if (length > max_length) {
					max_length = length;
				}
			}
			string[] details = {dgettext (null, "also check updates in AUR"),
								dgettext (null, "also check development packages updates (use with --aur)"),
								dgettext (null, "only print one line per update"),
								dgettext (null, "build directory (use with --devel), if no directory is given the one specified in pamac.conf file is used")};
			int i = 0;
			foreach (unowned string option in options) {
				string[] cuts = split_string (details[i], max_length + 3);
				print_aligned (option, " : %s".printf (cuts[0]), max_length);
				int j = 1;
				while (j < cuts.length) {
					print_aligned ("", "%s".printf (cuts[j]), max_length + 3);
					j++;
				}
				i++;
			}
		}

		void display_upgrade_help () {
			stdout.printf (dgettext (null, "Upgrade your system"));
			stdout.printf ("\n\n");
			stdout.printf ("pamac upgrade,update [%s]".printf (dgettext (null, "options")));
			stdout.printf ("\n\n");
			stdout.printf (dgettext (null, "options") + ":\n");
			int max_length = 0;
			string[] options = {"  -a, --aur",
								"  %s <%s>".printf ("--builddir", dgettext (null, "dir")),
								"  --force-refresh",
								"  --enable-downgrade",
								"  %s <%s>".printf ("--ignore", dgettext (null, "package(s)")),
								"  %s <%s>".printf ("--overwrite", dgettext (null, "glob")),
								"  --no-confirm"};
			foreach (unowned string option in options) {
				int length = option.char_count ();
				if (length > max_length) {
					max_length = length;
				}
			}
			string[] details = {dgettext (null, "also upgrade packages installed from AUR"),
								dgettext (null, "build directory (use with --aur), if no directory is given the one specified in pamac.conf file is used"),
								dgettext (null, "force the refresh of the databases"),
								dgettext (null, "enable package downgrades"),
								dgettext (null, "ignore a package upgrade, multiple packages can be specified by separating them with a comma"),
								dgettext (null, "overwrite conflicting files, multiple patterns can be specified by separating them with a comma"),
								dgettext (null, "bypass any and all confirmation messages")};
			int i = 0;
			foreach (unowned string option in options) {
				string[] cuts = split_string (details[i], max_length + 3);
				print_aligned (option, " : %s".printf (cuts[0]), max_length);
				int j = 1;
				while (j < cuts.length) {
					print_aligned ("", "%s".printf (cuts[j]), max_length + 3);
					j++;
				}
				i++;
			}
		}

		void display_clean_help () {
			stdout.printf (dgettext (null, "Clean packages cache or build files"));
			stdout.printf ("\n\n");
			stdout.printf ("pamac clean [%s]".printf (dgettext (null, "options")));
			stdout.printf ("\n\n");
			stdout.printf (dgettext (null, "options") + ":\n");
			int max_length = 0;
			string[] options = {"  %s <%s>".printf ("-k, --keep", dgettext (null, "number")),
								"  -u, --uninstalled",
								"  -b, --build-files",
								"  -d, --dry-run",
								"  -v, --verbose",
								"  --no-confirm"};
			foreach (unowned string option in options) {
				int length = option.char_count ();
				if (length > max_length) {
					max_length = length;
				}
			}
			string[] details = {dgettext (null, "specify how many versions of each package are kept in the cache directory"),
								dgettext (null, "only target uninstalled packages"),
								dgettext (null, "remove all build files, the build directory is the one specified in pamac.conf"),
								dgettext (null, "do not remove files, only find candidate packages"),
								dgettext (null, "also display all files names"),
								dgettext (null, "bypass any and all confirmation messages")};
			int i = 0;
			foreach (unowned string option in options) {
				string[] cuts = split_string (details[i], max_length + 3);
				print_aligned (option, " : %s".printf (cuts[0]), max_length);
				int j = 1;
				while (j < cuts.length) {
					print_aligned ("", "%s".printf (cuts[j]), max_length + 3);
					j++;
				}
				i++;
			}
		}

		async void search_pkgs (string search_string) {
			var installed_pkgs = database.search_installed_pkgs (search_string);
			var repos_pkgs = database.search_repos_pkgs (search_string);
			var aur_pkgs = new List<AURPackage> ();
			if (database.config.enable_aur) {
				aur_pkgs = yield database.search_in_aur (search_string);
				// sort aur pkgs by popularity
				aur_pkgs.sort ((pkg1, pkg2) => {
					double diff = pkg2.popularity - pkg1.popularity;
					if (diff < 0) {
						return -1;
					} else if (diff > 0) {
						return 1;
					} else {
						return 0;
					}
				});
			}
			int version_length = 0;
			int repo_length = 0;
			foreach (unowned Package pkg in installed_pkgs) {
				if (pkg.version.length > version_length) {
					version_length = pkg.version.length;
				}
				if (pkg.repo.length > repo_length) {
					repo_length = pkg.repo.length;
				}
			}
			foreach (unowned Package pkg in repos_pkgs) {
				if (pkg.version.length > version_length) {
					version_length = pkg.version.length;
				}
				if (pkg.repo.length > repo_length) {
					repo_length = pkg.repo.length;
				}
			}
			if (aur_pkgs.length () > 0) {
				foreach (unowned AURPackage aur_pkg in aur_pkgs) {
					if (aur_pkg.version.length > version_length) {
						version_length = aur_pkg.version.length;
					}
				}
				if (dgettext (null, "AUR").char_count () > repo_length) {
					repo_length = dgettext (null, "AUR").char_count ();
				}
			}
			int available_width = get_term_width () - (version_length + repo_length + 4);
			foreach (unowned Package pkg in installed_pkgs) {
				string installed = "[%s]".printf (dgettext (null, "Installed"));
				int installed_available_width = available_width - (installed.char_count () + 1);
				var str_builder = new StringBuilder ();
				str_builder.append (pkg.name);
				str_builder.append (" ");
				int diff = installed_available_width - pkg.name.length;
				if (diff > 0) {
					while (diff > 0) {
						str_builder.append (" ");
						diff--;
					}
				}
				str_builder.append (installed);
				str_builder.append (" ");
				str_builder.append ("%-*s  %s \n".printf (version_length, pkg.version, pkg.repo));
				stdout.printf ("%s", str_builder.str);
				string[] cuts = split_string (pkg.desc, 2, available_width);
				foreach (unowned string cut in cuts) {
					print_aligned ("", cut, 2);
				}
			}
			foreach (unowned Package pkg in repos_pkgs) {
				var str_builder = new StringBuilder ();
				str_builder.append (pkg.name);
				str_builder.append (" ");
				int diff = available_width - pkg.name.length;
				if (diff > 0) {
					while (diff > 0) {
						str_builder.append (" ");
						diff--;
					}
				}
				str_builder.append ("%-*s  %s \n".printf (version_length, pkg.version, pkg.repo));
				stdout.printf ("%s", str_builder.str);
				string[] cuts = split_string (pkg.desc, 2, available_width);
				foreach (unowned string cut in cuts) {
					print_aligned ("", cut, 2);
				}
			}
			if (aur_pkgs.length () > 0) {
				if (installed_pkgs.length () > 0 || repos_pkgs.length () > 0) {
					stdout.printf ("\n");
				}
				foreach (unowned AURPackage aur_pkg in aur_pkgs) {
					var str_builder = new StringBuilder ();
					string name = aur_pkg.name;
					if (aur_pkg.installed_version != "") {
						if (aur_pkg.outofdate != 0) {
							var time = GLib.Time.local ((time_t) aur_pkg.outofdate);
							name = "%s [%s] (%s: %s)".printf (aur_pkg.name, dgettext (null, "Installed"),
															dgettext (null, "Out of Date"), time.format ("%x"));
						} else {
							name = "%s [%s]".printf (aur_pkg.name, dgettext (null, "Installed"));
						}
					} else if (aur_pkg.outofdate != 0) {
						var time = GLib.Time.local ((time_t) aur_pkg.outofdate);
						name = "%s (%s: %s)".printf (aur_pkg.name, dgettext (null, "Out of Date"), time.format ("%x"));
					}
					str_builder.append (name);
					str_builder.append (" ");
					int diff = available_width - name.char_count ();
					if (diff > 0) {
						while (diff > 0) {
							str_builder.append (" ");
							diff--;
						}
					}
					str_builder.append ("%-*s  %s \n".printf (version_length, aur_pkg.version, dgettext (null, "AUR")));
					stdout.printf ("%s", str_builder.str);
					string[] cuts = split_string (aur_pkg.desc, 2, available_width);
					foreach (unowned string cut in cuts) {
						print_aligned ("", cut, 2);
					}
				}
			}
		}

		async void display_pkg_infos (string[] pkgnames) {
			string[] in_repos = {};
			string[] not_in_repos = {};
			foreach (unowned string pkgname in pkgnames) {
				var details =  database.get_pkg_details (pkgname, "", false);
				if (details.name == "") {
					not_in_repos += pkgname;
				} else {
					in_repos += pkgname;
				}
			}
			if (in_repos.length > 0) {
				yield display_repo_infos (in_repos);
			}
			if (not_in_repos.length > 0) {
				yield display_aur_infos (not_in_repos);
			}
		}

		async void display_repo_infos (string[] pkgnames) {
			string[] properties = { dgettext (null, "Name"),
									dgettext (null, "Version"),
									dgettext (null, "Description"),
									dgettext (null, "URL"),
									dgettext (null, "Licenses"),
									dgettext (null, "Repository"),
									dgettext (null, "Size"),
									dgettext (null, "Groups"),
									dgettext (null, "Depends On"),
									dgettext (null, "Optional Dependencies"),
									dgettext (null, "Required By"),
									dgettext (null, "Optional For"),
									dgettext (null, "Provides"),
									dgettext (null, "Replaces"),
									dgettext (null, "Conflicts With"),
									dgettext (null, "Packager"),
									dgettext (null, "Build Date"),
									dgettext (null, "Install Date"),
									dgettext (null, "Install Reason"),
									dgettext (null, "Signatures"),
									dgettext (null, "Backup files"),
									dgettext (null, "Package Base"),
									dgettext (null, "Maintainer"),
									dgettext (null, "First Submitted"),
									dgettext (null, "Last Modified"),
									dgettext (null, "Votes"),
									dgettext (null, "Out of Date")};
			int max_length = 0;
			foreach (unowned string prop in properties) {
				// use char_count to handle special characters
				if (prop.char_count () > max_length) {
					max_length = prop.length;
				}
			}
			foreach (unowned string pkgname in pkgnames) {
				var details =  database.get_pkg_details (pkgname, "", false);
				if (details.name == "") {
					print_error (dgettext (null, "target not found: %s").printf (pkgname));
					continue;
				}
				// Name
				print_aligned (properties[0], ": %s".printf (details.name), max_length);
				// Version
				print_aligned (properties[1], ": %s".printf (details.version), max_length);
				// Description
				string[] cuts = split_string (details.desc, max_length + 2);
				print_aligned (properties[2], ": %s".printf (cuts[0]), max_length);
				int i = 1;
				while (i < cuts.length) {
					print_aligned ("", "%s".printf (cuts[i]), max_length + 2);
					i++;
				}
				// URL
				print_aligned (properties[3], ": %s".printf (details.url), max_length);
				// Licenses
				print_aligned (properties[4], ": %s".printf (details.licenses.nth_data (0)), max_length);
				i = 1;
				while (i < details.licenses.length ()) {
					print_aligned ("", "%s".printf (details.licenses.nth_data (i)), max_length + 2);
					i++;
				}
				// Repository
				if (details.repo != "") {
					print_aligned (properties[5], ": %s".printf (dgettext (null, "AUR")), max_length);
				}
				// Size
				print_aligned (properties[6], ": %s".printf (format_size (details.size)), max_length);
				if (details.repo == dgettext (null, "AUR")) {
					AURPackageDetails aur_pkg_details = yield database.get_aur_pkg_details (details.name);
					// Package Base
					if (aur_pkg_details.packagebase != details.name) {
						print_aligned (properties[21], ": %s".printf (aur_pkg_details.packagebase), max_length);
					}
					// Maintainer
					if (aur_pkg_details.maintainer != "") {
						print_aligned (properties[22], ": %s".printf (aur_pkg_details.maintainer), max_length);
					}
					// First Submitted
					if (aur_pkg_details.firstsubmitted != 0) {
						var time = GLib.Time.local ((time_t) aur_pkg_details.firstsubmitted);
						print_aligned (properties[23], ": %s".printf (time.format ("%x")), max_length);
					}
					// Last Modified
					if (aur_pkg_details.lastmodified != 0) {
						var time = GLib.Time.local ((time_t) aur_pkg_details.lastmodified);
						print_aligned (properties[24], ": %s".printf (time.format ("%x")), max_length);
					}
					// Votes
					if (aur_pkg_details.numvotes != 0) {
						print_aligned (properties[25], ": %s".printf (aur_pkg_details.numvotes.to_string ()), max_length);
					}
					// Out of Date
					if (aur_pkg_details.outofdate != 0) {
						var time = GLib.Time.local ((time_t) aur_pkg_details.outofdate);
						print_aligned (properties[26], ": %s".printf (time.format ("%x")), max_length);
					}
				}
				// Groups
				if (details.groups.length () > 0) {
					cuts = split_string (concatenate_strings_list (details.groups), max_length + 2);
					print_aligned (properties[7], ": %s".printf (cuts[0]), max_length);
					i = 1;
					while (i < cuts.length) {
						print_aligned ("", "%s".printf (cuts[i]), max_length + 2);
						i++;
					}
				}
				// Depends
				if (details.depends.length () > 0) {
					cuts = split_string (concatenate_strings_list (details.depends), max_length + 2);
					print_aligned (properties[8], ": %s".printf (cuts[0]), max_length);
					i = 1;
					while (i < cuts.length) {
						print_aligned ("", "%s".printf (cuts[i]), max_length + 2);
						i++;
					}
				}
				// Opt depends
				if (details.optdepends.length () > 0) {
					string depstring = details.optdepends.nth_data (0);
					var satisfier = database.find_installed_satisfier (depstring);
					if (satisfier.name != "") {
						depstring = "%s [%s]".printf (depstring, dgettext (null, "Installed"));
					}
					cuts = split_string (depstring, max_length + 2);
					print_aligned (properties[9], ": %s".printf (cuts[0]), max_length);
					i = 1;
					while (i < cuts.length) {
						print_aligned ("", "%s".printf (cuts[i]), max_length + 2);
						i++;
					}
					i = 1;
					while (i < details.optdepends.length ()) {
						depstring = details.optdepends.nth_data (i);
						satisfier = database.find_installed_satisfier (depstring);
						if (satisfier.name != "") {
							depstring = "%s [%s]".printf (depstring, dgettext (null, "Installed"));
						}
						cuts = split_string (depstring, max_length + 2);
						int j = 0;
						while (j < cuts.length) {
							print_aligned ("", "%s".printf (cuts[j]), max_length + 2);
							j++;
						}
						i++;
					}
				}
				// Required by
				if (details.requiredby.length () > 0) {
					cuts = split_string (concatenate_strings_list (details.requiredby), max_length + 2);
					print_aligned (properties[10], ": %s".printf (cuts[0]), max_length);
					i = 1;
					while (i < cuts.length) {
						print_aligned ("", "%s".printf (cuts[i]), max_length + 2);
						i++;
					}
				}
				// Optional for
				if (details.optionalfor.length () > 0) {
					cuts = split_string (concatenate_strings_list (details.optionalfor), max_length + 2);
					print_aligned (properties[11], ": %s".printf (cuts[0]), max_length);
					i = 1;
					while (i < cuts.length) {
						print_aligned ("", "%s".printf (cuts[i]), max_length + 2);
						i++;
					}
				}
				// Provides
				if (details.provides.length () > 0) {
					cuts = split_string (concatenate_strings_list (details.provides), max_length + 2);
					print_aligned (properties[12], ": %s".printf (cuts[0]), max_length);
					i = 1;
					while (i < cuts.length) {
						print_aligned ("", "%s".printf (cuts[i]), max_length + 2);
						i++;
					}
				}
				// Replaces
				if (details.replaces.length () > 0) {
					cuts = split_string (concatenate_strings_list (details.replaces), max_length + 2);
					print_aligned (properties[13], ": %s".printf (cuts[0]), max_length);
					i = 1;
					while (i < cuts.length) {
						print_aligned ("", "%s".printf (cuts[i]), max_length + 2);
						i++;
					}
				}
				// Conflicts
				if (details.conflicts.length () > 0) {
					cuts = split_string (concatenate_strings_list (details.conflicts), max_length + 2);
					print_aligned (properties[14], ": %s".printf (cuts[0]), max_length);
					i = 1;
					while (i < cuts.length) {
						print_aligned ("", "%s".printf (cuts[i]), max_length + 2);
						i++;
					}
				}
				// Packager
				cuts = split_string (details.packager, max_length + 2);
				print_aligned (properties[15], ": %s".printf (cuts[0]), max_length);
				i = 1;
				while (i < cuts.length) {
					print_aligned ("", "%s".printf (cuts[i]), max_length + 2);
					i++;
				}
				// Build date
				var time = GLib.Time.local ((time_t) details.builddate);
				print_aligned (properties[16], ": %s".printf (time.format ("%x")), max_length);
				// Install date
				if (details.installdate != 0) {
					time = GLib.Time.local ((time_t) details.installdate);
					print_aligned (properties[17], ": %s".printf (time.format ("%x")), max_length);
				}
				// Reason
				if (details.reason != "") {
					cuts = split_string (details.reason, max_length + 2);
					print_aligned (properties[18], ": %s".printf (cuts[0]), max_length);
					i = 1;
					while (i < cuts.length) {
						print_aligned ("", "%s".printf (cuts[i]), max_length + 2);
						i++;
					}
				}
				// Signature
				if (details.has_signature != "") {
					print_aligned (properties[19], ": %s".printf (details.has_signature), max_length);
				}
				// Backup files
				if (details.backups.length () > 0) {
					print_aligned (properties[20], ": %s".printf (details.backups.nth_data (0)), max_length);
					i = 1;
					while (i < details.backups.length ()) {
						print_aligned ("", "%s".printf (details.backups.nth_data (i)), max_length + 2);
						i++;
					}
				}
				stdout.printf ("\n");
			}
		}

		async void display_aur_infos (string[] pkgnames) {
			string[] properties = { dgettext (null, "Name"),
									dgettext (null, "Package Base"),
									dgettext (null, "Version"),
									dgettext (null, "Description"),
									dgettext (null, "URL"),
									dgettext (null, "Licenses"),
									dgettext (null, "Repository"),
									dgettext (null, "Depends On"),
									dgettext (null, "Make Dependencies"),
									dgettext (null, "Check Dependencies"),
									dgettext (null, "Optional Dependencies"),
									dgettext (null, "Provides"),
									dgettext (null, "Replaces"),
									dgettext (null, "Conflicts With"),
									dgettext (null, "Maintainer"),
									dgettext (null, "First Submitted"),
									dgettext (null, "Last Modified"),
									dgettext (null, "Votes"),
									dgettext (null, "Out of Date")};
			int max_length = 0;
			foreach (unowned string prop in properties) {
				// use char_count to handle special characters
				if (prop.char_count () > max_length) {
					max_length = prop.length;
				}
			}
			var aur_pkgs = yield database.get_aur_pkgs_details (pkgnames);
			var iter = HashTableIter<string, AURPackageDetails> (aur_pkgs);
			unowned string pkgname;
			unowned AURPackageDetails details;
			while (iter.next (out pkgname, out details)) {
				if (details.name == "") {
					print_error (dgettext (null, "target not found: %s").printf (pkgname));
					return;
				}
				// Name
				print_aligned (properties[0], ": %s".printf (details.name), max_length);
				// Package Base
				if (details.packagebase != details.name) {
					print_aligned (properties[1], ": %s".printf (details.packagebase), max_length);
				}
				// Version
				print_aligned (properties[2], ": %s".printf (details.version), max_length);
				// Description
				string[] cuts = split_string (details.desc, max_length + 2);
				print_aligned (properties[3], ": %s".printf (cuts[0]), max_length);
				int i = 1;
				while (i < cuts.length) {
					print_aligned ("", "%s".printf (cuts[i]), max_length + 2);
					i++;
				}
				// URL
				print_aligned (properties[4], ": %s".printf (details.url), max_length);
				// Licenses
				print_aligned (properties[5], ": %s".printf (details.licenses.nth_data (0)), max_length);
				i = 1;
				while (i < details.licenses.length ()) {
					print_aligned ("", "%s".printf (details.licenses.nth_data (i)), max_length + 2);
					i++;
				}
				// Repository
				print_aligned (properties[6], ": %s".printf (dgettext (null, "AUR")), max_length);
				// Depends
				if (details.depends.length () > 0) {
					cuts = split_string (concatenate_strings_list (details.depends), max_length + 2);
					print_aligned (properties[7], ": %s".printf (cuts[0]), max_length);
					i = 1;
					while (i < cuts.length) {
						print_aligned ("", "%s".printf (cuts[i]), max_length + 2);
						i++;
					}
				}
				// Make Depends
				if (details.makedepends.length () > 0) {
					cuts = split_string (concatenate_strings_list (details.makedepends), max_length + 2);
					print_aligned (properties[8], ": %s".printf (cuts[0]), max_length);
					i = 1;
					while (i < cuts.length) {
						print_aligned ("", "%s".printf (cuts[i]), max_length + 2);
						i++;
					}
				}
				// Check Depends
				if (details.checkdepends.length () > 0) {
					cuts = split_string (concatenate_strings_list (details.checkdepends), max_length + 2);
					print_aligned (properties[9], ": %s".printf (cuts[0]), max_length);
					i = 1;
					while (i < cuts.length) {
						print_aligned ("", "%s".printf (cuts[i]), max_length + 2);
						i++;
					}
				}
				// Opt depends
				if (details.optdepends.length () > 0) {
					string depstring = details.optdepends.nth_data (0);
					var satisfier = database.find_installed_satisfier (depstring);
					if (satisfier.name != "") {
						depstring = "%s [%s]".printf (depstring, dgettext (null, "Installed"));
					}
					cuts = split_string (depstring, max_length + 2);
					print_aligned (properties[10], ": %s".printf (cuts[0]), max_length);
					i = 1;
					while (i < cuts.length) {
						print_aligned ("", "%s".printf (cuts[i]), max_length + 2);
						i++;
					}
					i = 1;
					while (i < details.optdepends.length ()) {
						depstring = details.optdepends.nth_data (i);
						satisfier = database.find_installed_satisfier (depstring);
						if (satisfier.name != "") {
							depstring = "%s [%s]".printf (depstring, dgettext (null, "Installed"));
						}
						cuts = split_string (depstring, max_length + 2);
						int j = 0;
						while (j < cuts.length) {
							print_aligned ("", "%s".printf (cuts[j]), max_length + 2);
							j++;
						}
						i++;
					}
				}
				// Provides
				if (details.provides.length () > 0) {
					cuts = split_string (concatenate_strings_list (details.provides), max_length + 2);
					print_aligned (properties[11], ": %s".printf (cuts[0]), max_length);
					i = 1;
					while (i < cuts.length) {
						print_aligned ("", "%s".printf (cuts[i]), max_length + 2);
						i++;
					}
				}
				// Replaces
				if (details.replaces.length () > 0) {
					cuts = split_string (concatenate_strings_list (details.replaces), max_length + 2);
					print_aligned (properties[12], ": %s".printf (cuts[0]), max_length);
					i = 1;
					while (i < cuts.length) {
						print_aligned ("", "%s".printf (cuts[i]), max_length + 2);
						i++;
					}
				}
				// Conflicts
				if (details.conflicts.length () > 0) {
					cuts = split_string (concatenate_strings_list (details.conflicts), max_length + 2);
					print_aligned (properties[13], ": %s".printf (cuts[0]), max_length);
					i = 1;
					while (i < cuts.length) {
						print_aligned ("", "%s".printf (cuts[i]), max_length + 2);
						i++;
					}
				}
				// Maintainer
				if (details.maintainer != "") {
					print_aligned (properties[14], ": %s".printf (details.maintainer), max_length);
				}
				// First Submitted
				var time = GLib.Time.local ((time_t) details.firstsubmitted);
				print_aligned (properties[15], ": %s".printf (time.format ("%x")), max_length);
				// Last Modified
				time = GLib.Time.local ((time_t) details.lastmodified);
				print_aligned (properties[16], ": %s".printf (time.format ("%x")), max_length);
				// Votes
				print_aligned (properties[17], ": %s".printf (details.numvotes.to_string ()), max_length);
				// Out of Date
				if (details.outofdate != 0) {
					time = GLib.Time.local ((time_t) details.outofdate);
					print_aligned (properties[18], ": %s".printf (time.format ("%x")), max_length);
				}
				stdout.printf ("\n");
			}
		}

		void print_pkgs (List<Package> pkgs, bool print_installed) {
			int name_length = 0;
			int version_length = 0;
			int repo_length = 0;
			foreach (unowned Package pkg in pkgs) {
				string name = pkg.name;
				if (print_installed && pkg.installed_version != "") {
					name = "%s [%s]".printf (pkg.name, dgettext (null, "Installed"));
				}
				int current_name_length = name.char_count ();
				if (current_name_length > name_length) {
					name_length = current_name_length;
				}
				if (pkg.version.length > version_length) {
					version_length = pkg.version.length;
				}
				if (pkg.repo.length > repo_length) {
					repo_length = pkg.repo.length;
				}
			}
			foreach (unowned Package pkg in pkgs) {
				// use this code to correctly aligned text with special characters
				var str_builder = new StringBuilder ();
				string name = pkg.name;
				if (print_installed && pkg.installed_version != "") {
					name = "%s [%s]".printf (pkg.name, dgettext (null, "Installed"));
				}
				str_builder.append (name);
				str_builder.append (" ");
				int diff = name_length - name.char_count ();
				if (diff > 0) {
					while (diff > 0) {
						str_builder.append (" ");
						diff--;
					}
				}
				str_builder.append ("%-*s  %-*s  %s\n".printf (
									version_length, pkg.version,
									repo_length, pkg.repo,
									format_size (pkg.size)));
				stdout.printf ("%s", str_builder.str);
			}
		}

		void list_installed () {
			var pkgs = database.get_installed_pkgs ();
			print_pkgs (pkgs, false);
		}

		void list_orphans () {
			var pkgs = database.get_orphans ();
			print_pkgs (pkgs, false);
		}

		void list_foreign () {
			var pkgs = database.get_foreign_pkgs ();
			print_pkgs (pkgs, false);
		}

		void list_groups (string[] names) {
			if (names.length == 0) {
				var grpnames = database.get_groups_names ();
				foreach (unowned string name in grpnames) {
					stdout.printf ("%s\n", name);
				}
				return;
			}
			foreach (unowned string name in names) {
				var pkgs = database.get_group_pkgs (name);
				if (pkgs.length () == 0) {
					print_error (dgettext (null, "target not found: %s").printf (name));
				} else {
					print_pkgs (pkgs, true);
				}
				stdout.printf ("\n");
			}
		}

		void list_repos (string[] names) {
			if (names.length == 0) {
				var grpnames = database.get_repos_names ();
				foreach (unowned string name in grpnames) {
					stdout.printf ("%s\n", name);
				}
				return;
			}
			foreach (unowned string name in names) {
				var pkgs = database.get_repo_pkgs (name);
				if (pkgs.length () == 0) {
					print_error (dgettext (null, "target not found: %s").printf (name));
				} else {
					print_pkgs (pkgs, true);
				}
				stdout.printf ("\n");
			}
		}

		void list_files (string[] names) {
			foreach (unowned string name in names) {
				var files = database.get_pkg_files (name);
				if (files.length () == 0) {
					print_error (dgettext (null, "target not found: %s").printf (name));
				} else {
					foreach (unowned string path in files) {
						stdout.printf ("%s\n", path);
					}
				}
				stdout.printf ("\n");
			}
		}

		void search_files (string[] files) {
			HashTable<string, Variant> result = database.search_files (files);
			if (result.size () == 0) {
				foreach (unowned string file in files) {
					stdout.printf ("%s\n", dgettext (null, "No package owns %s").printf (file));
				}
				exit_status = 1;
				return;
			}
			var iter = HashTableIter<string, Variant> (result);
			unowned string pkgname;
			unowned Variant files_list;
			while (iter.next (out pkgname, out files_list)) {
				foreach (unowned string file in (string[]) files_list) {
					stdout.printf ("%s\n", dgettext (null, "%s is owned by %s").printf (file, pkgname));
				}
			}
		}

		async void checkupdates (bool quiet, bool refresh_tmp_files_dbs, bool download_updates) {
			var updates = yield database.get_updates ();
			uint updates_nb = updates.repos_updates.length () + updates.aur_updates.length ();
			if (updates_nb == 0) {
				if (quiet) {
					return;
				}
				stdout.printf ("%s.\n", dgettext (null, "Your system is up-to-date"));
				if (updates.outofdate.length () > 0) {
					// print out of date pkgs
					stdout.printf ("\n%s:\n", dgettext (null, "Out of Date"));
					int name_length = 0;
					int version_length = 0;
					foreach (unowned AURPackage pkg in updates.outofdate) {
						if (pkg.name.length > name_length) {
							name_length = pkg.name.length;
						}
						if (pkg.version.length > version_length) {
							version_length = pkg.version.length;
						}
					}
					foreach (unowned AURPackage pkg in updates.outofdate) {
						stdout.printf ("%-*s  %-*s  %s\n",
										name_length, pkg.name,
										version_length, pkg.version,
										dgettext (null, "AUR"));
					}
				}
			} else {
				// special status when updates are available
				exit_status = 100;
				// refresh tmp files dbs
				if (refresh_tmp_files_dbs) {
					database.refresh_tmp_files_dbs ();
				}
				// download updates
				if (download_updates) {
					transaction = new TransactionCli (database);
					transaction.downloading_updates_finished.connect (() => {
						Idle.add (checkupdates.callback);
					});
					transaction.start_downloading_updates ();
					yield;
				}
				if (quiet) {
					foreach (unowned Package pkg in updates.repos_updates) {
						stdout.printf ("%s  %s -> %s\n", pkg.name, pkg.installed_version, pkg.version);
					}
					foreach (unowned AURPackage pkg in updates.aur_updates) {
						// do not show out of date packages
						if (pkg.outofdate == 0) {
							stdout.printf ("%s  %s\n", pkg.name, pkg.version);
						}
					}
					return;
				}
				// print pkgs
				int name_length = 0;
				int version_length = 0;
				foreach (unowned Package pkg in updates.repos_updates) {
					if (pkg.name.length > name_length) {
						name_length = pkg.name.length;
					}
					if (pkg.version.length > version_length) {
						version_length = pkg.version.length;
					}
				}
				foreach (unowned AURPackage pkg in updates.aur_updates) {
					if (pkg.name.length > name_length) {
						name_length = pkg.name.length;
					}
					if (pkg.version.length > version_length) {
						version_length = pkg.version.length;
					}
				}
				foreach (unowned AURPackage pkg in updates.outofdate) {
					if (pkg.name.length > name_length) {
						name_length = pkg.name.length;
					}
					if (pkg.version.length > version_length) {
						version_length = pkg.version.length;
					}
				}
				string info = ngettext ("%u available update", "%u available updates", updates_nb).printf (updates_nb);
				stdout.printf ("%s:\n", info);
				foreach (unowned Package pkg in updates.repos_updates) {
					stdout.printf ("%-*s  %-*s  %s\n",
									name_length, pkg.name,
									version_length, pkg.version,
									pkg.repo);
				}
				foreach (unowned AURPackage pkg in updates.aur_updates) {
					stdout.printf ("%-*s  %-*s  %s\n",
									name_length, pkg.name,
									version_length, pkg.version,
									dgettext (null, "AUR"));
				}
				if (updates.outofdate.length () > 0) {
					// print out of date pkgs
					stdout.printf ("\n%s:\n", dgettext (null, "Out of Date"));
					foreach (unowned AURPackage pkg in updates.outofdate) {
						stdout.printf ("%-*s  %-*s  %s\n",
										name_length, pkg.name,
										version_length, pkg.version,
										dgettext (null, "AUR"));
					}
				}
			}
		}

		bool ask_user (string question) {
			// ask user confirmation
			stdout.printf ("%s %s ", question, dgettext (null, "[y/N]"));
			char buf[32];
			if (stdin.gets (buf) != null) {
				string ans = (string) buf;
				// remove trailing newline and uppercase
				ans = ans.replace ("\n", "").down ();
				// just return use default
				if (ans != "") {
					if (ans == dgettext (null, "y") ||
						ans == dgettext (null, "yes")) {
						return true;
					}
				}
			}
			return false;
		}

		void clean_cache (bool dry_run, bool verbose, bool no_confirm) {
			HashTable<string, int64?> details = database.get_clean_cache_details (database.config.clean_keep_num_pkgs, database.config.clean_rm_only_uninstalled);
			int64 total_size = 0;
			var filenames = new SList<string> ();
			var iter = HashTableIter<string, int64?> (details);
			unowned string filename;
			int64? size;
			while (iter.next (out filename, out size)) {
				total_size += size;
				filenames.append (filename);
			}
			if (database.config.clean_rm_only_uninstalled) {
				stdout.printf ("%s\n", dgettext (null, "Remove only the versions of uninstalled packages"));
			}
			stdout.printf ("%s: %llu\n\n", dgettext (null, "Number of versions of each package to keep in the cache"), database.config.clean_keep_num_pkgs);
			uint files_nb = filenames.length ();
			if (verbose && files_nb > 0) {
				filenames.sort (database.vercmp);
				foreach (unowned string name in filenames) {
					stdout.printf ("%s\n", name);
				}
				stdout.printf ("\n");
			}
			stdout.printf ("%s: %s  (%s)\n".printf (dgettext (null, "To delete"), dngettext (null, "%u file", "%u files", files_nb).printf (files_nb), format_size (total_size)));
			if (files_nb == 0 || dry_run) {
				return;
			}
			if (no_confirm || ask_user ("%s ?".printf (dgettext (null, "Clean cache")))) {
				try_lock_and_run (clean_cache_real);
			}
		}

		void clean_cache_real () {
			transaction.clean_cache_finished.connect (on_clean_cache_finished);
			transaction.start_clean_cache (database.config.clean_keep_num_pkgs, database.config.clean_rm_only_uninstalled);
			loop.run ();
		}

		void on_clean_cache_finished () {
			transaction.clean_cache_finished.disconnect (on_clean_cache_finished);
			transaction.unlock ();
			loop.quit ();
		}

		void clean_build_files (bool dry_run, bool verbose, bool no_confirm) {
			HashTable<string, int64?> details = database.get_build_files_details (database.config.aur_build_dir);
			int64 total_size = 0;
			var filenames = new SList<string> ();
			var iter = HashTableIter<string, int64?> (details);
			unowned string filename;
			int64? size;
			while (iter.next (out filename, out size)) {
				total_size += size;
				filenames.append (filename);
			}
			uint files_nb = filenames.length ();
			if (verbose && files_nb > 0) {
				filenames.sort (strcmp);
				foreach (unowned string name in filenames) {
					stdout.printf ("%s\n", name);
				}
				stdout.printf ("\n");
			}
			stdout.printf ("%s: %s  (%s)\n".printf (dgettext (null, "To delete"), dngettext (null, "%u file", "%u files", files_nb).printf (files_nb), format_size (total_size)));
			if (files_nb == 0 || dry_run) {
				return;
			}
			if (no_confirm || ask_user ("%s ?".printf (dgettext (null, "Clean build files")))) {
				try_lock_and_run (clean_build_files_real);
			}
		}

		void clean_build_files_real () {
			transaction.clean_build_files_finished.connect (on_clean_build_files_finished);
			transaction.start_clean_build_files (database.config.aur_build_dir);
			loop.run ();
		}

		void on_clean_build_files_finished () {
			transaction.clean_build_files_finished.disconnect (on_clean_build_files_finished);
			transaction.unlock ();
			loop.quit ();
		}

		void install_pkgs (string[] targets) {
			foreach (unowned string target in targets) {
				bool found = false;
				// check for local or remote path
				if (".pkg.tar" in target) {
					if ("://" in target) {
						if ("file://" in target) {
							// handle file:// uri
							var file = File.new_for_uri (target);
							string? absolute_path = file.get_path ();
							if (absolute_path != null) {
								to_load += absolute_path;
								found = true;
							}
						} else {
							// add url in to_load, pkg will be downloaded by system_daemon
							to_load += target;
							found = true;
						}
					} else {
						// handle local or absolute path
						var file = File.new_for_path (target);
						string? absolute_path = file.get_path ();
						if (absolute_path != null) {
							to_load += absolute_path;
							found = true;
						}
					}
				} else {
					var pkg = database.find_sync_satisfier (target);
					if (pkg.name != "") {
						to_install += target;
						found = true;
					} else {
						var groupnames = database.get_groups_names ();
						if (groupnames.find_custom (target, strcmp) != null) {
							ask_group_confirmation (target);
							found = true;
						}
					}
				}
				if (!found) {
					print_error (dgettext (null, "target not found: %s").printf (target));
					return;
				}
			}
			if (to_install.length == 0 && to_load.length == 0) {
				stdout.printf (dgettext (null, "Nothing to do") + ".\n");
				return;
			}
			// do not install a package if it is already installed and up to date
			transaction.flags = (1 << 13); //Alpm.TransFlag.NEEDED
			try_lock_and_run (start_transaction);
		}

		void ask_group_confirmation (string grpname) {
			var pkgs = database.get_group_pkgs (grpname);
			if (transaction.no_confirm) {
				foreach (unowned Package pkg in pkgs) {
					to_install += pkg.name;
				}
				return;
			}
			// print pkgs
			int name_length = 0;
			int version_length = 0;
			foreach (unowned Package pkg in pkgs) {
				if (pkg.name.length > name_length) {
					name_length = pkg.name.length;
				}
				if (pkg.version.length > version_length) {
					version_length = pkg.version.length;
				}
			}
			int num_length = pkgs.length ().to_string ().length + 1;
			stdout.printf ("%s:\n".printf (dngettext (null, "There is %u member in group %s",
						"There are %u members in group %s", pkgs.length ()).printf (pkgs.length (), grpname)));
			int num = 1;
			foreach (unowned Package pkg in pkgs) {
				stdout.printf ("%*s  %-*s  %-*s  %s\n",
								num_length, "%i:".printf (num),
								name_length, pkg.name,
								version_length, pkg.version,
								pkg.repo);
				num++;
			}
			// get user input
			while (true) {
				stdout.printf ("\n");
				stdout.printf ("%s: ", dgettext (null, "Enter a selection (default=%s)").printf (dgettext (null, "all")));
				string ans = stdin.read_line ();
				uint64 nb;
				uint64[] numbers = {};
				// remvove trailing newline
				ans = ans.replace ("\n", "");
				// just return use default
				if (ans == "") {
					foreach (unowned Package pkg in pkgs) {
						to_install += pkg.name;
					}
					break;
				} else {
					// split ","
					string[] splitted = ans.split (",");
					foreach (unowned string part in splitted) {
						// check for range
						if ("-" in part) {
							string[] splitted2 = part.split ("-", 2);
							// get all numbers in range
							int64 beg_num, end_num;
							if (int64.try_parse (splitted2[0], out beg_num)) {
								if (int64.try_parse (splitted2[1], out end_num)) {
									nb = beg_num;
									while (nb <= end_num) {
										if (nb >= 1 && nb < pkgs.length ()) {
											numbers += nb;
										}
										nb++;
									}
								}
							}
						} else if (uint64.try_parse (part, out nb)) {
							if (nb >= 1 && nb < pkgs.length ()) {
								numbers += nb;
							}
						}
					}
				}
				if (numbers.length > 0) {
					foreach (uint64 number in numbers) {
						to_install += pkgs.nth_data ((uint) number -1).name;
					}
					break;
				}
			}
			stdout.printf ("\n");
		}

		void reinstall_pkgs (string[] names) {
			foreach (unowned string name in names) {
				bool found = false;
				string version = "";
				var local_pkg = database.get_installed_pkg (name);
				if (local_pkg.name != "") {
					version = local_pkg.version;
					var sync_pkg = database.get_sync_pkg (name);
					if (sync_pkg.name != "") {
						if (local_pkg.version == sync_pkg.version) {
							to_install += name;
							found = true;
						}
					}
				} else {
					var groupnames = database.get_groups_names ();
					if (groupnames.find_custom (name, strcmp) != null) {
						found = true;
						var pkgs = database.get_group_pkgs (name);
						foreach (unowned Package pkg in pkgs) {
							if (pkg.version == pkg.installed_version) {
								to_install += pkg.name;
							}
						}
					}
				}
				if (!found) {
					if (version == "") {
						print_error (dgettext (null, "target not found: %s").printf (name));
					} else {
						print_error (dgettext (null, "target not found: %s").printf (name + "-" + version));
					}
					return;
				}
			}
			if (to_install.length == 0) {
				stdout.printf (dgettext (null, "Nothing to do") + ".\n");
				return;
			}
			try_lock_and_run (start_transaction);
		}

		void remove_pkgs (string[] names, bool recurse = false) {
			bool group_found = false;
			foreach (unowned string name in names) {
				bool found = false;
				if (database.is_installed_pkg (name)) {
					to_remove += name;
					found = true;
				} else {
					var groupnames = database.get_groups_names ();
					if (groupnames.find_custom (name, strcmp) != null) {
						found = true;
						var pkgs = database.get_group_pkgs (name);
						foreach (unowned Package pkg in pkgs) {
							if (pkg.version == pkg.installed_version) {
								to_remove += pkg.name;
								group_found = true;
							}
						}
					}
				}
				if (!found) {
					print_error (dgettext (null, "target not found: %s").printf (name));
					return;
				}
			}
			if (to_remove.length == 0) {
				stdout.printf (dgettext (null, "Nothing to do") + ".\n");
				return;
			}
			if (group_found) {
				transaction.flags = (1 << 15); //Alpm.TransFlag.UNNEEDED
			} else {
				transaction.flags = (1 << 4); //Alpm.TransFlag.CASCADE
			}
			if (recurse) {
				transaction.flags |= (1 << 5); //Alpm.TransFlag.RECURSE
			}
			try_lock_and_run (start_transaction);
		}

		void remove_orphans () {
			var pkgs = database.get_orphans ();
			foreach (unowned Package pkg in pkgs) {
				to_remove += pkg.name;
			}
			transaction.flags = (1 << 4); //Alpm.TransFlag.CASCADE
			transaction.flags |= (1 << 5); //Alpm.TransFlag.RECURSE
			try_lock_and_run (start_transaction);
		}

		void clone_build_files (string[] pkgnames, bool overwrite, bool recurse) {
			already_checked_aur_dep = new GenericSet<string?> (str_hash, str_equal);
			// set waiting to allow cancellation
			waiting = true;
			clone_build_files_real.begin (pkgnames, overwrite, recurse, () => {
				waiting = false;
				loop.quit ();
			});
			loop.run ();
		}

		async void clone_build_files_real (string[] pkgnames, bool overwrite, bool recurse) {
			string[] dep_to_check = {};
			var aur_pkgs = yield database.get_aur_pkgs_details (pkgnames);
			var iter = HashTableIter<string, AURPackageDetails> (aur_pkgs);
			unowned string pkgname;
			unowned AURPackageDetails aur_pkg_details;
			while (iter.next (out pkgname, out aur_pkg_details)) {
				if (aur_pkg_details.name == "") {
					print_error (dgettext (null, "target not found: %s").printf (pkgname));
					continue;
				} else {
					// clone build files
					stdout.printf (dgettext (null, "Cloning %s build files".printf (pkgname)) + "...\n");
					// use packagebase in case of split package
					File? clone_dir = yield database.clone_build_files (aur_pkg_details.packagebase, overwrite);
					if (clone_dir == null) {
						// error
						return;
					} else if (recurse) {
						var depends = new List<string> ();
						foreach (unowned string depend in aur_pkg_details.depends) {
							depends.append (depend);
						}
						foreach (unowned string depend in aur_pkg_details.makedepends) {
							depends.append (depend);
						}
						foreach (unowned string depend in aur_pkg_details.checkdepends) {
							depends.append (depend);
						}
						// check deps
						foreach (unowned string dep_string in depends) {
							var pkg = database.find_installed_satisfier (dep_string);
							if (pkg.name == "") {
								pkg = database.find_sync_satisfier (dep_string);
							}
							if (pkg.name == "") {
								string dep_name = database.get_alpm_dep_name (dep_string);
								if (!(dep_name in already_checked_aur_dep)) {
									already_checked_aur_dep.add (dep_name);
									dep_to_check += (owned) dep_name;
								}
							}
						}
					}
				}
			}
			if (dep_to_check.length > 0) {
				yield clone_build_files_real (dep_to_check, overwrite, recurse);
			}
		}

		async bool check_build_pkgs (string[] targets) {
			var aur_pkgs = yield database.get_aur_pkgs (targets);
			var iter = HashTableIter<string, AURPackage> (aur_pkgs);
			unowned string pkgname;
			unowned AURPackage aur_pkg;
			while (iter.next (out pkgname, out aur_pkg)) {
				if (aur_pkg.name == "") {
					print_error (dgettext (null, "target not found: %s").printf (pkgname));
					return false;
				}
			}
			return true;
		}

		void build_pkgs (string[] to_build) {
			this.to_build = to_build;
			try_lock_and_run (start_transaction);
		}

		void start_transaction () {
			transaction.start (to_install, to_remove, to_load, to_build, temporary_ignorepkgs, overwrite_files);
			loop.run ();
		}

		void try_lock_and_run (TransactionAction action) {
			if (transaction.get_lock ()) {
				action ();
			} else {
				waiting = true;
				stdout.printf (dgettext (null, "Waiting for another package manager to quit") + "...\n");
				Timeout.add (5000, () => {
					if (!waiting) {
						return false;
					}
					bool locked = transaction.get_lock ();
					if (locked) {
						loop.quit ();
						waiting = false;
						action ();
					}
					return !locked;
				});
				loop.run ();
			}
		}

		void start_sysupgrade () {
			if (Posix.geteuid () != 0) {
				// let's time to pkttyagent to get registred
				Timeout.add (200, () => {
					transaction.start_sysupgrade (force_refresh, database.config.enable_downgrade, temporary_ignorepkgs, overwrite_files);
					return false;
				});
			} else {
				transaction.start_sysupgrade (force_refresh, database.config.enable_downgrade, temporary_ignorepkgs, overwrite_files);
			}
			loop.run ();
		}

		void on_transaction_finished (bool success) {
			transaction.unlock ();
			loop.quit ();
			if (!success) {
				exit_status = 1;
			}
		}

		public static int main (string[] args) {
			// i18n
			Intl.textdomain ("pamac");
			Intl.setlocale (LocaleCategory.ALL, "");
			// run
			loop = new MainLoop ();
			var cli = new Cli();
			cli.parse_command_line (args);
			// stop system_daemon
			if (cli.transaction != null) {
				cli.transaction.quit_daemon ();
			}
			if (cli.pkttyagent != null) {
				cli.pkttyagent.force_exit ();
			}
			return cli.exit_status;
		}
	}
}

