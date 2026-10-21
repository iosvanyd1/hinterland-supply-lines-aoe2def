"""`python -m hinterland <command>`"""
import argparse
import logging
import sys

from hinterland import assemble, config, lint, package


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="hinterland")
    sub = parser.add_subparsers(dest="command", required=True)

    b = sub.add_parser("build", help="Assemble build/<ModName> (data mod + XS) and the Text mod")
    b.add_argument("--no-dat", action="store_true", help="Skip the data mod (XS only)")
    b.add_argument("--dev", action="store_true",
                   help="Local test build 'HinterlandSupplyLinesDev', titled '(dev)'; no Text mod")
    b.add_argument("--ai-affected", action="store_true",
                   help="With --dev: computer players are affected by the mod (for testing); "
                        "release builds always exempt them")
    sub.add_parser("lint", help="Run xs-check on the XS entry point")
    sub.add_parser("package", help="Zip the data mod and the Text mod into dist/ for upload")
    sub.add_parser("paths", help="Print the resolved game paths")

    args = parser.parse_args(argv)
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    mod = config.load_mod_info()

    if args.command == "build":
        paths = None if args.no_dat else config.load_game_paths()
        if args.ai_affected and not args.dev:
            parser.error("--ai-affected is for --dev builds only; a release must exempt the AI")
        if args.dev:
            assemble.assemble(assemble.dev_mod(mod), paths, with_dat=not args.no_dat, text_mod=False,
                              ai_affected=args.ai_affected)
        else:
            assemble.assemble(mod, paths, with_dat=not args.no_dat)
        return 0
    if args.command == "lint":
        return lint.lint()
    if args.command == "package":
        for out in package.package(mod):
            print(out)
        return 0
    if args.command == "paths":
        paths = config.load_game_paths()
        print(f"install_dir : {paths.install_dir} (exists: {paths.install_dir.exists()})")
        print(f"vanilla_dat : {paths.vanilla_dat} (exists: {paths.vanilla_dat.exists()})")
        print(f"profile_dir : {paths.profile_dir}")
        print(f"local mods  : {paths.local_mods_dir}")
        return 0
    return 1


if __name__ == "__main__":
    sys.exit(main())
