"""Install the matching official iOS template without downloading the full TPZ."""

import argparse
from fetch_web_template import fetch_template


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", default="4.7.2")
    args = parser.parse_args()
    fetch_template(args.version, "ios.zip")


if __name__ == "__main__":
    main()
