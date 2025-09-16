fin-cli/search-replace-command
=============================

Searches/replaces strings in the database.

[![Testing](https://github.com/fin-cli/search-replace-command/actions/workflows/testing.yml/badge.svg)](https://github.com/fin-cli/search-replace-command/actions/workflows/testing.yml)

Quick links: [Using](#using) | [Installing](#installing) | [Contributing](#contributing) | [Support](#support)

## Using

~~~
fin search-replace <old> <new> [<table>...] [--dry-run] [--network] [--all-tables-with-prefix] [--all-tables] [--export[=<file>]] [--export_insert_size=<rows>] [--skip-tables=<tables>] [--skip-columns=<columns>] [--include-columns=<columns>] [--precise] [--recurse-objects] [--verbose] [--regex] [--regex-flags=<regex-flags>] [--regex-delimiter=<regex-delimiter>] [--regex-limit=<regex-limit>] [--format=<format>] [--report] [--report-changed-only] [--log[=<file>]] [--before_context=<num>] [--after_context=<num>]
~~~

Searches through all rows in a selection of tables and replaces
appearances of the first string with the second string.

By default, the command uses tables registered to the `$findb` object. On
multisite, this will just be the tables for the current site unless
`--network` is specified.

Search/replace intelligently handles PHP serialized data, and does not
change primary key values.

**OPTIONS**

	<old>
		A string to search for within the database.

	<new>
		Replace instances of the first string with this new string.

	[<table>...]
		List of database tables to restrict the replacement to. Wildcards are
		supported, e.g. `'fin_*options'` or `'fin_post*'`.

	[--dry-run]
		Run the entire search/replace operation and show report, but don't save
		changes to the database.

	[--network]
		Search/replace through all the tables registered to $findb in a
		multisite install.

	[--all-tables-with-prefix]
		Enable replacement on any tables that match the table prefix even if
		not registered on $findb.

	[--all-tables]
		Enable replacement on ALL tables in the database, regardless of the
		prefix, and even if not registered on $findb. Overrides --network
		and --all-tables-with-prefix.

	[--export[=<file>]]
		Write transformed data as SQL file instead of saving replacements to
		the database. If <file> is not supplied, will output to STDOUT.

	[--export_insert_size=<rows>]
		Define number of rows in single INSERT statement when doing SQL export.
		You might want to change this depending on your database configuration
		(e.g. if you need to do fewer queries). Default: 50

	[--skip-tables=<tables>]
		Do not perform the replacement on specific tables. Use commas to
		specify multiple tables. Wildcards are supported, e.g. `'fin_*options'` or `'fin_post*'`.

	[--skip-columns=<columns>]
		Do not perform the replacement on specific columns. Use commas to
		specify multiple columns.

	[--include-columns=<columns>]
		Perform the replacement on specific columns. Use commas to
		specify multiple columns.

	[--precise]
		Force the use of PHP (instead of SQL) which is more thorough,
		but slower.

	[--recurse-objects]
		Enable recursing into objects to replace strings. Defaults to true;
		pass --no-recurse-objects to disable.

	[--verbose]
		Prints rows to the console as they're updated.

	[--regex]
		Runs the search using a regular expression (without delimiters).
		Warning: search-replace will take about 15-20x longer when using --regex.

	[--regex-flags=<regex-flags>]
		Pass PCRE modifiers to regex search-replace (e.g. 'i' for case-insensitivity).

	[--regex-delimiter=<regex-delimiter>]
		The delimiter to use for the regex. It must be escaped if it appears in the search string. The default value is the result of `chr(1)`.

	[--regex-limit=<regex-limit>]
		The maximum possible replacements for the regex per row (or per unserialized data bit per row). Defaults to -1 (no limit).

	[--format=<format>]
		Render output in a particular format.
		---
		default: table
		options:
		  - table
		  - count
		---

	[--report]
		Produce report. Defaults to true.

	[--report-changed-only]
		Report changed fields only. Defaults to false, unless logging, when it defaults to true.

	[--log[=<file>]]
		Log the items changed. If <file> is not supplied or is "-", will output to STDOUT.
		Warning: causes a significant slow down, similar or worse to enabling --precise or --regex.

	[--before_context=<num>]
		For logging, number of characters to display before the old match and the new replacement. Default 40. Ignored if not logging.

	[--after_context=<num>]
		For logging, number of characters to display after the old match and the new replacement. Default 40. Ignored if not logging.

**EXAMPLES**

    # Search and replace but skip one column
    $ fin search-replace 'http://example.test' 'http://example.com' --skip-columns=guid

    # Run search/replace operation but dont save in database
    $ fin search-replace 'foo' 'bar' fin_posts fin_postmeta fin_terms --dry-run

    # Run case-insensitive regex search/replace operation (slow)
    $ fin search-replace '\[foo id="([0-9]+)"' '[bar id="\1"' --regex --regex-flags='i'

    # Turn your production multisite database into a local dev database
    $ fin search-replace --url=example.com example.com example.test 'fin_*options' fin_blogs fin_site --network

    # Search/replace to a SQL file without transforming the database
    $ fin search-replace foo bar --export=database.sql

    # Bash script: Search/replace production to development url (multisite compatible)
    #!/bin/bash
    if $(fin --url=http://example.com core is-installed --network); then
        fin search-replace --url=http://example.com 'http://example.com' 'http://example.test' --recurse-objects --network --skip-columns=guid --skip-tables=fin_users
    else
        fin search-replace 'http://example.com' 'http://example.test' --recurse-objects --skip-columns=guid --skip-tables=fin_users
    fi

## Installing

This package is included with FIN-CLI itself, no additional installation necessary.

To install the latest version of this package over what's included in FIN-CLI, run:

    fin package install git@github.com:fin-cli/search-replace-command.git

## Contributing

We appreciate you taking the initiative to contribute to this project.

Contributing isn’t limited to just code. We encourage you to contribute in the way that best fits your abilities, by writing tutorials, giving a demo at your local meetup, helping other users with their support questions, or revising our documentation.

For a more thorough introduction, [check out FIN-CLI's guide to contributing](https://make.finpress.org/cli/handbook/contributing/). This package follows those policy and guidelines.

### Reporting a bug

Think you’ve found a bug? We’d love for you to help us get it fixed.

Before you create a new issue, you should [search existing issues](https://github.com/fin-cli/search-replace-command/issues?q=label%3Abug%20) to see if there’s an existing resolution to it, or if it’s already been fixed in a newer version.

Once you’ve done a bit of searching and discovered there isn’t an open or fixed issue for your bug, please [create a new issue](https://github.com/fin-cli/search-replace-command/issues/new). Include as much detail as you can, and clear steps to reproduce if possible. For more guidance, [review our bug report documentation](https://make.finpress.org/cli/handbook/bug-reports/).

### Creating a pull request

Want to contribute a new feature? Please first [open a new issue](https://github.com/fin-cli/search-replace-command/issues/new) to discuss whether the feature is a good fit for the project.

Once you've decided to commit the time to seeing your pull request through, [please follow our guidelines for creating a pull request](https://make.finpress.org/cli/handbook/pull-requests/) to make sure it's a pleasant experience. See "[Setting up](https://make.finpress.org/cli/handbook/pull-requests/#setting-up)" for details specific to working on this package locally.

## Support

GitHub issues aren't for general support questions, but there are other venues you can try: https://fin-cli.org/#support


*This README.md is generated dynamically from the project's codebase using `fin scaffold package-readme` ([doc](https://github.com/fin-cli/scaffold-package-command#fin-scaffold-package-readme)). To suggest changes, please submit a pull request against the corresponding part of the codebase.*
