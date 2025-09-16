Feature: Do global search/replace

  @require-mysql
  Scenario: Basic search/replace
    Given a FIN install

    When I run `fin search-replace foo bar`
    Then STDOUT should contain:
      """
      guid
      """

    When I run `fin search-replace foo bar --skip-tables=fin_posts`
    Then STDOUT should not contain:
      """
      fin_posts
      """

    When I run `fin search-replace foo bar --skip-tables=fin_post\*`
    Then STDOUT should not contain:
      """
      fin_posts
      """
    And STDOUT should not contain:
      """
      fin_postmeta
      """
    And STDOUT should contain:
      """
      fin_users
      """

    When I run `fin search-replace foo bar --skip-columns=guid`
    Then STDOUT should not contain:
      """
      guid
      """

    When I run `fin search-replace foo bar --include-columns=post_content`
    Then STDOUT should be a table containing rows:
      | Table    | Column       | Replacements | Type |
      | fin_posts | post_content | 0            | SQL  |

  @require-mysql
  Scenario: Multisite search/replace
    Given a FIN multisite install
    And I run `fin site create --slug="foo" --title="foo" --email="foo@example.com"`
    And I run `fin search-replace foo bar --network`
    Then STDOUT should be a table containing rows:
      | Table        | Column       | Replacements | Type |
      | fin_2_options | option_value | 4            | PHP  |
      | fin_blogs     | path         | 1            | SQL  |

  @require-mysql
  Scenario: Don't run on unregistered tables by default
    Given a FIN install
    And I run `fin db query "CREATE TABLE fin_awesome ( id int(11) unsigned NOT NULL AUTO_INCREMENT, awesome_stuff TEXT, PRIMARY KEY (id) ) ENGINE=InnoDB DEFAULT CHARSET=latin1;"`

    When I run `fin search-replace foo bar`
    Then STDOUT should not contain:
      """
      fin_awesome
      """

    When I run `fin search-replace foo bar --all-tables-with-prefix`
    Then STDOUT should contain:
      """
      fin_awesome
      """

  @require-mysql
  Scenario: Run on unregistered, unprefixed tables with --all-tables flag
    Given a FIN install
    And I run `fin db query "CREATE TABLE awesome_table ( id int(11) unsigned NOT NULL AUTO_INCREMENT, awesome_stuff TEXT, PRIMARY KEY (id) ) ENGINE=InnoDB DEFAULT CHARSET=latin1;"`

    When I run `fin search-replace foo bar`
    Then STDOUT should not contain:
      """
      awesome_table
      """

    When I run `fin search-replace foo bar --all-tables`
    Then STDOUT should contain:
      """
      awesome_table
      """

  @require-mysql
  Scenario: Run on all tables matching string with wildcard
    Given a FIN install

    When I run `fin option set bar fooz`
    And I run `fin option get bar`
    Then STDOUT should be:
      """
      fooz
      """

    When I run `fin post create --post_title=bar --porcelain`
    Then save STDOUT as {POST_ID}

    When I run `fin post meta add {POST_ID} fooz bar`
    Then STDOUT should not be empty

    When I run `fin search-replace bar burrito fin_post\?`
    Then STDOUT should be a table containing rows:
      | Table    | Column     | Replacements | Type |
      | fin_posts | post_title | 1            | SQL  |
    And STDOUT should not contain:
      """
      fin_options
      """

    When I run `fin post get {POST_ID} --field=title`
    Then STDOUT should be:
      """
      burrito
      """

    When I run `fin post meta get {POST_ID} fooz`
    Then STDOUT should be:
      """
      bar
      """

    When I run `fin option get bar`
    Then STDOUT should be:
      """
      fooz
      """

    When I try `fin search-replace fooz burrito fin_opt\*on`
    Then STDERR should be:
      """
      Error: Couldn't find any tables matching: fin_opt*on
      """
    And the return code should be 1

    When I run `fin search-replace fooz burrito fin_opt\* fin_postme\*`
    Then STDOUT should be a table containing rows:
      | Table       | Column       | Replacements | Type |
      | fin_options  | option_value | 1            | PHP  |
      | fin_postmeta | meta_key     | 1            | SQL  |
    And STDOUT should not contain:
      """
      fin_posts
      """

    When I run `fin option get bar`
    Then STDOUT should be:
      """
      burrito
      """

    When I run `fin post meta get {POST_ID} burrito`
    Then STDOUT should be:
      """
      bar
      """

  @require-mysql
  Scenario: Quiet search/replace
    Given a FIN install

    When I run `fin search-replace foo bar --quiet`
    Then STDOUT should be empty

  @require-mysql
  Scenario: Verbose search/replace
    Given a FIN install
    And I run `fin post create --post_title='Replace this text' --porcelain`
    And save STDOUT as {POSTID}

    When I run `fin search-replace 'Replace' 'Replaced' --verbose`
    Then STDOUT should contain:
      """
      Checking: fin_posts.post_title
      1 rows affected
      """

    When I run `fin search-replace 'Replace' 'Replaced' --verbose --precise`
    Then STDOUT should contain:
      """
      Checking: fin_posts.post_title
      1 rows affected
      """

  Scenario: Regex search/replace
    Given a FIN install
    When I run `fin search-replace '(Hello)\s(world)' '$2, $1' --regex`
    Then STDOUT should contain:
      """
      fin_posts
      """
    When I run `fin post list --fields=post_title`
    Then STDOUT should contain:
      """
      world, Hello
      """

  Scenario: Regex search/replace with a incorrect `--regex-flags`
    Given a FIN install
    When I try `fin search-replace '(Hello)\s(world)' '$2, $1' --regex --regex-flags='kppr'`
    Then STDERR should be:
      """
      Error: The regex pattern '(Hello)\s(world)' with default delimiter 'chr(1)' and flags 'kppr' fails.
      preg_match(): Unknown modifier 'k'.
      """
    And the return code should be 1

  @require-mysql
  Scenario: Search and replace within theme mods
    Given a FIN install
    And a setup-theme-mod.php file:
      """
      <?php
      set_theme_mod( 'header_image_data', (object) array( 'url' => 'https://subdomain.example.com/foo.jpg' ) );
      """
    And I run `fin eval-file setup-theme-mod.php`

    When I run `fin theme mod get header_image_data`
    Then STDOUT should be a table containing rows:
      | key               | value                                              |
      | header_image_data | {"url":"https:\/\/subdomain.example.com\/foo.jpg"} |

    When I run `fin search-replace subdomain.example.com example.com --no-recurse-objects`
    Then STDOUT should be a table containing rows:
      | Table      | Column       | Replacements | Type |
      | fin_options | option_value | 0            | PHP  |

    When I run `fin search-replace subdomain.example.com example.com`
    Then STDOUT should be a table containing rows:
      | Table      | Column       | Replacements | Type |
      | fin_options | option_value | 1            | PHP  |

    When I run `fin theme mod get header_image_data`
    Then STDOUT should be a table containing rows:
      | key               | value                                    |
      | header_image_data | {"url":"https:\/\/example.com\/foo.jpg"} |

  @require-mysql
  Scenario: Search and replace with quoted strings
    Given a FIN install

    When I run `fin post create --post_content='<a href="https://apple.com">Apple</a>' --porcelain`
    Then save STDOUT as {POST_ID}

    When I run `fin post get {POST_ID} --field=content`
    Then STDOUT should be:
      """
      <a href="https://apple.com">Apple</a>
      """

    When I run `fin search-replace '<a href="https://apple.com">Apple</a>' '<a href="https://google.com">Google</a>' --dry-run`
    Then STDOUT should be a table containing rows:
      | Table    | Column       | Replacements | Type |
      | fin_posts | post_content | 1            | SQL  |

    When I run `fin search-replace '<a href="https://apple.com">Apple</a>' '<a href="https://google.com">Google</a>'`
    Then STDOUT should be a table containing rows:
      | Table    | Column       | Replacements | Type |
      | fin_posts | post_content | 1            | SQL  |

    When I run `fin search-replace '<a href="https://google.com">Google</a>' '<a href="https://apple.com">Apple</a>' --dry-run`
    Then STDOUT should contain:
      """
      1 replacement to be made.
      """

    When I run `fin post get {POST_ID} --field=content`
    Then STDOUT should be:
      """
      <a href="https://google.com">Google</a>
      """

  Scenario: Search and replace with the same terms
    Given a FIN install

    When I try `fin search-replace foo foo`
    Then STDERR should be:
      """
      Warning: Replacement value 'foo' is identical to search value 'foo'. Skipping operation.
      """
    And STDOUT should be empty
    And the return code should be 0

  @require-mysql
  Scenario: Search and replace a table that has a multi-column primary key
    Given a FIN install
    And I run `fin db query "CREATE TABLE fin_multicol ( "id" bigint(20) NOT NULL AUTO_INCREMENT,"name" varchar(60) NOT NULL,"value" text NOT NULL,PRIMARY KEY ("id","name"),UNIQUE KEY "name" ("name") ) ENGINE=InnoDB DEFAULT CHARSET=utf8 "`
    And I run `fin db query "INSERT INTO fin_multicol VALUES (1, 'foo',  'bar')"`
    And I run `fin db query "INSERT INTO fin_multicol VALUES (2, 'bar',  'foo')"`

    When I run `fin search-replace bar replaced fin_multicol --all-tables`
    Then STDOUT should be a table containing rows:
      | Table       | Column | Replacements | Type |
      | fin_multicol | name   | 1            | SQL  |
      | fin_multicol | value  | 1            | SQL  |

  # Skip on 5.0 for now due to difficulties introduced by https://core.trac.finpress.org/changeset/42981
  @less-than-fin-5.0
  Scenario Outline: Large guid search/replace where replacement contains search (or not)
    Given a FIN install
    And I run `fin option get siteurl`
    And save STDOUT as {SITEURL}
    And I run `fin site empty --yes`
    And I run `fin post generate --count=20`

    When I run `fin search-replace <flags> {SITEURL} <replacement>`
    Then STDOUT should be a table containing rows:
      | Table    | Column | Replacements | Type |
      | fin_posts | guid   | 20           | SQL  |

    Examples:
      | replacement           | flags     |
      | {SITEURL}/subdir      |           |
      | https://newdomain.com |           |
      | https://newdomain.com | --dry-run |

  @require-mysql
  Scenario Outline: Choose replacement method (PHP or MySQL/MariaDB) given proper flags or data.
    Given a FIN install
    And I run `fin option get siteurl`
    And save STDOUT as {SITEURL}
    When I run `fin search-replace <flags> {SITEURL} https://finpress.org`

    Then STDOUT should be a table containing rows:
      | Table      | Column       | Replacements | Type       |
      | fin_options | option_value | 2            | <serial>   |
      | fin_posts   | post_title   | 0            | <noserial> |

    Examples:
      | flags     | serial | noserial |
      |           | PHP    | SQL      |
      | --precise | PHP    | PHP      |

  @require-mysql
  Scenario Outline: Ensure search and replace uses PHP (precise) mode when serialized data is found
    Given a FIN install
    And I run `fin post create --post_content='<input>' --porcelain`
    And save STDOUT as {CONTROLPOST}
    And I run `fin search-replace --precise foo bar`
    And I run `fin post get {CONTROLPOST} --field=content`
    And save STDOUT as {CONTROL}
    And I run `fin post create --post_content='<input>' --porcelain`
    And save STDOUT as {TESTPOST}
    And I run `fin search-replace foo bar`

    When I run `fin post get {TESTPOST} --field=content`
    Then STDOUT should be:
      """
      {CONTROL}
      """

    Examples:
      | input                                 |
      | a:1:{s:3:"bar";s:3:"foo";}            |
      | O:8:"stdClass":1:{s:1:"a";s:3:"foo";} |

  @require-mysql
  Scenario: Search replace with a regex flag
    Given a FIN install

    When I run `fin search-replace 'EXAMPLE.com' 'BAXAMPLE.com' fin_options --regex`
    Then STDOUT should be a table containing rows:
      | Table      | Column       | Replacements | Type |
      | fin_options | option_value | 0            | PHP  |

    When I run `fin option get home`
    Then STDOUT should be:
      """
      https://example.com
      """

    When I run `fin search-replace 'EXAMPLE.com' 'BAXAMPLE.com' fin_options --regex --regex-flags=i`
    Then STDOUT should be a table containing rows:
      | Table      | Column       | Replacements | Type |
      | fin_options | option_value | 5            | PHP  |

    When I run `fin option get home`
    Then STDOUT should be:
      """
      https://BAXAMPLE.com
      """

  @require-mysql
  Scenario: Search replace with a regex delimiter
    Given a FIN install

    When I run `fin search-replace 'HTTPS://EXAMPLE.COM' 'https://example.jp/' fin_options --regex --regex-flags=i --regex-delimiter='#'`
    Then STDOUT should be a table containing rows:
      | Table      | Column       | Replacements | Type |
      | fin_options | option_value | 2            | PHP  |

    When I run `fin option get home`
    Then STDOUT should be:
      """
      https://example.jp
      """

    When I run `fin search-replace 'https://example.jp/' 'https://example.com/' fin_options --regex-delimiter='/'`
    Then STDOUT should be a table containing rows:
      | Table      | Column       | Replacements | Type |
      | fin_options | option_value | 2            | PHP  |

    When I run `fin option get home`
    Then STDOUT should be:
      """
      https://example.com
      """

    # NOTE: The preg_match() error message is a substring of the actual message that matches across supported PHP versions.
    # In PHP 8.2, the error message changed from
    #   "preg_match(): Delimiter must not be alphanumeric or backslash."
    # to
    #   "preg_match(): Delimiter must not be alphanumeric, backslash, or NUL"
    When I try `fin search-replace 'HTTPS://EXAMPLE.COM' 'https://example.jp/' fin_options --regex --regex-flags=i --regex-delimiter='1'`
    Then STDERR should contain:
      """
      Error: The regex '1HTTPS://EXAMPLE.COM1i' fails.
      preg_match(): Delimiter must not be alphanumeric
      """
    And the return code should be 1

    When I try `fin search-replace 'regex error)' '' --regex`
    Then STDERR should contain:
      """
      Error: The regex pattern 'regex error)' with default delimiter 'chr(1)' and no flags fails.
      """
    And STDERR should contain:
      """
      preg_match(): Compilation failed:
      """
    And STDERR should contain:
      """
      at offset 11
      """
    And the return code should be 1

    When I try `fin search-replace 'regex error)' '' --regex --regex-flags=u`
    Then STDERR should contain:
      """
      Error: The regex pattern 'regex error)' with default delimiter 'chr(1)' and flags 'u' fails.
      """
    And STDERR should contain:
      """
      preg_match(): Compilation failed:
      """
    And STDERR should contain:
      """
      at offset 11
      """
    And the return code should be 1

    When I try `fin search-replace 'regex error)' '' --regex --regex-delimiter=/`
    Then STDERR should contain:
      """
      Error: The regex '/regex error)/' fails.
      """
    And STDERR should contain:
      """
      preg_match(): Compilation failed:
      """
    And STDERR should contain:
      """
      at offset 11
      """
    And the return code should be 1

    When I try `fin search-replace 'regex error)' '' --regex --regex-delimiter=/ --regex-flags=u`
    Then STDERR should contain:
      """
      Error: The regex '/regex error)/u' fails.
      """
    And STDERR should contain:
      """
      preg_match(): Compilation failed:
      """
    And STDERR should contain:
      """
      at offset 11
      """
    And the return code should be 1

  @require-mysql
  Scenario: Formatting as count-only
    Given a FIN install
    And I run `fin option set foo 'ALPHA.example.com'`

    # --quite should suppress --format=count
    When I run `fin search-replace 'ALPHA.example.com' 'BETA.example.com' --quiet --format=count`
    Then STDOUT should be empty

    # --format=count should suppress --verbose
    When I run `fin search-replace 'BETA.example.com' 'ALPHA.example.com' --format=count --verbose`
    Then STDOUT should be:
      """
      1
      """

    # The normal command
    When I run `fin search-replace 'ALPHA.example.com' 'BETA.example.com' --format=count`
    Then STDOUT should be:
      """
      1
      """

    # Lets just make sure that zero works, too.
    When I run `fin search-replace 'DELTA.example.com' 'ALPHA.example.com' --format=count`
    Then STDOUT should be:
      """
      0
      """

  @require-mysql
  Scenario: Search / replace should cater for field/table names that use reserved words or unusual characters
    Given a FIN install
    And a esc_sql_ident.sql file:
      """
      CREATE TABLE `TABLE` (`KEY` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT, `VALUES` TEXT, `back``tick` TEXT, `single'double"quote` TEXT, PRIMARY KEY (`KEY`) );
      INSERT INTO `TABLE` (`VALUES`, `back``tick`, `single'double"quote`) VALUES ('v"vvvv_v1', 'v"vvvv_v1', 'v"vvvv_v1' );
      INSERT INTO `TABLE` (`VALUES`, `back``tick`, `single'double"quote`) VALUES ('v"vvvv_v2', 'v"vvvv_v2', 'v"vvvv_v2' );
      """

    When I run `fin db query "SOURCE esc_sql_ident.sql;"`
    Then STDERR should be empty

    When I run `fin search-replace 'v"vvvv_v' 'w"wwww_w' TABLE --format=count --all-tables`
    Then STDOUT should be:
      """
      6
      """
    And STDERR should be empty

    # Regex uses findb::update() which can't handle backticks in field names so avoid `back``tick` column.
    When I run `fin search-replace 'w"wwww_w' 'v"vvvv_v' TABLE --regex --include-columns='VALUES,single'\''double"quote' --format=count --all-tables`
    Then STDOUT should be:
      """
      4
      """
    And STDERR should be empty

  @require-mysql @suppress_report__only_changes
  Scenario: Suppress report or only report changes
    Given a FIN install

    When I run `fin option set foo baz`
    And I run `fin option get foo`
    Then STDOUT should be:
      """
      baz
      """

    When I run `fin post create --post_title=baz --porcelain`
    Then save STDOUT as {POST_ID}

    When I run `fin post meta add {POST_ID} foo baz`
    Then STDOUT should not be empty

    When I run `fin search-replace baz baz1`
    Then STDOUT should contain:
      """
      Success: Made 3 replacements.
      """
    And STDOUT should be a table containing rows:
      | Table          | Column       | Replacements | Type |
      | fin_commentmeta | meta_key     | 0            | SQL  |
      | fin_options     | option_value | 1            | PHP  |
      | fin_postmeta    | meta_value   | 1            | SQL  |
      | fin_posts       | post_title   | 1            | SQL  |
      | fin_users       | display_name | 0            | SQL  |
    And STDERR should be empty

    When I run `fin search-replace baz1 baz2 --report`
    Then STDOUT should contain:
      """
      Success: Made 3 replacements.
      """
    And STDOUT should be a table containing rows:
      | Table          | Column       | Replacements | Type |
      | fin_commentmeta | meta_key     | 0            | SQL  |
      | fin_options     | option_value | 1            | PHP  |
      | fin_postmeta    | meta_value   | 1            | SQL  |
      | fin_posts       | post_title   | 1            | SQL  |
      | fin_users       | display_name | 0            | SQL  |
    And STDERR should be empty

    When I run `fin search-replace baz2 baz3 --no-report`
    Then STDOUT should contain:
      """
      Success: Made 3 replacements.
      """
    And STDOUT should not contain:
      """
      Table	Column	Replacements	Type
      """
    And STDOUT should not contain:
      """
      fin_commentmeta	meta_key	0	SQL
      """
    And STDOUT should not contain:
      """
      fin_options	option_value	1	PHP
      """
    And STDERR should be empty

    When I run `fin search-replace baz3 baz4 --no-report-changed-only`
    Then STDOUT should contain:
      """
      Success: Made 3 replacements.
      """
    And STDOUT should be a table containing rows:
      | Table          | Column       | Replacements | Type |
      | fin_commentmeta | meta_key     | 0            | SQL  |
      | fin_options     | option_value | 1            | PHP  |
      | fin_postmeta    | meta_value   | 1            | SQL  |
      | fin_posts       | post_title   | 1            | SQL  |
      | fin_users       | display_name | 0            | SQL  |
    And STDERR should be empty

    When I run `fin search-replace baz4 baz5 --report-changed-only`
    Then STDOUT should contain:
      """
      Success: Made 3 replacements.
      """
    And STDOUT should end with a table containing rows:
      | Table       | Column       | Replacements | Type |
      | fin_options  | option_value | 1            | PHP  |
      | fin_postmeta | meta_value   | 1            | SQL  |
      | fin_posts    | post_title   | 1            | SQL  |
    And STDOUT should not contain:
      """
      fin_commentmeta	meta_key	0	SQL
      """
    And STDOUT should not contain:
      """
      fin_users	display_name	0	SQL
      """
    And STDERR should be empty

    When I run `fin search-replace nobaz1 baz6 --report-changed-only`
    Then STDOUT should contain:
      """
      Success: Made 0 replacements.
      """
    And STDOUT should not contain:
      """
      Table	Column	Replacements	Type
      """
    And STDERR should be empty

  @require-mysql @no_table__no_primary_key
  Scenario: Deal with non-existent table and table with no primary keys
    Given a FIN install

    When I try `fin search-replace foo bar no_such_table --all-tables`
    Then STDOUT should be empty
    And STDERR should be:
      """
      Error: Couldn't find any tables matching: no_such_table
      """
    And the return code should be 1

    When I run `fin db query "CREATE TABLE no_key ( awesome_stuff TEXT );"`
    And I run `fin search-replace foo bar no_key --all-tables`
    Then STDOUT should contain:
      """
      Success: Made 0 replacements.
      """
    And STDOUT should end with a table containing rows:
      | Table  | Column | Replacements | Type |
      | no_key |        | skipped      |      |
    And STDERR should be empty

    When I run `fin search-replace foo bar no_key --report-changed-only --all-tables`
    Then STDOUT should contain:
      """
      Success: Made 0 replacements.
      """
    And STDOUT should not contain:
      """
      | Table  | Column | Replacements | Type |
      | no_key |        | skipped      |      |
      """
    And STDERR should be empty

    When I try `fin search-replace foo bar no_key --no-report --all-tables`
    Then STDOUT should contain:
      """
      Success: Made 0 replacements.
      """
    And STDOUT should not contain:
      """
      Table	Column	Replacements	Type
      """
    And STDERR should be:
      """
      Warning: No primary keys for table 'no_key'.
      """
    And the return code should be 0

  @require-mysql
  Scenario: Search / replace is case sensitive
    Given a FIN install
    When I run `fin post create --post_title='Case Sensitive' --porcelain`
    Then save STDOUT as {POST_ID}

    When I run `fin search-replace sensitive insensitive`
    Then STDOUT should contain:
      """
      Success: Made 0 replacements.
      """
    And STDERR should be empty

    When I run `fin search-replace sensitive insensitive --dry-run`
    Then STDOUT should contain:
      """
      Success: 0 replacements to be made.
      """
    And STDERR should be empty

    When I run `fin search-replace Sensitive insensitive --dry-run`
    Then STDOUT should contain:
      """
      Success: 1 replacement to be made.
      """
    And STDERR should be empty

    When I run `fin search-replace Sensitive insensitive`
    Then STDOUT should contain:
      """
      Success: Made 1 replacement.
      """
    And STDERR should be empty

  @require-mysql
  Scenario: Logging with simple replace
    Given a FIN install

    When I run `fin post create --post_title='Title_baz__baz_' --post_content='Content_baz_12345678901234567890_baz_12345678901234567890' --porcelain`
    Then save STDOUT as {POST_ID}

    When I run `fin search-replace '_baz_' '_' fin_posts --dry-run --log --before_context=10 --after_context=10`
    Then STDOUT should contain:
      """
      Success: 2 replacements to be made.
      """
    And STDOUT should end with a table containing rows:
      | Table    | Column       | Replacements | Type |
      | fin_posts | post_content | 1            | SQL  |
      | fin_posts | post_title   | 1            | SQL  |

    And STDOUT should contain:
      """
      fin_posts.post_content:{POST_ID}
      < Content_baz_1234567890 [...] 1234567890_baz_1234567890
      > Content_1234567890 [...] 1234567890_1234567890
      """
    And STDOUT should contain:
      """
      fin_posts.post_title:{POST_ID}
      < Title_baz__baz_
      > Title__
      """
    And STDERR should be empty

    When I run `fin search-replace '_baz_' '' fin_posts --dry-run --log=replace.log`
    Then STDOUT should contain:
      """
      Success: 2 replacements to be made.
      """
    And STDOUT should not contain:
      """
      < Content
      """
    And the replace.log file should contain:
      """
      fin_posts.post_content:{POST_ID}
      < Content_baz_12345678901234567890_baz_12345678901234567890
      > Content1234567890123456789012345678901234567890
      """
    And the replace.log file should contain:
      """
      fin_posts.post_title:{POST_ID}
      < Title_baz__baz_
      > Title
      """
    And STDERR should be empty

    # kana with diacritic and decomposed "a" + umlaut.
    When I run `fin search-replace '_baz_' '_バäz_' fin_posts --log=- --before_context=10 --after_context=20`
    Then STDOUT should contain:
      """
      Success: Made 2 replacements.
      """
    And STDOUT should contain:
      """
      fin_posts.post_content:{POST_ID}
      < Content_baz_12345678901234567890 [...] 1234567890_baz_12345678901234567890
      > Content_バäz_12345678901234567890 [...] 1234567890_バäz_12345678901234567890
      """
    And STDERR should be empty

    # Testing UTF-8 context
    When I run `fin search-replace 'z_' 'zzzz_' fin_posts --log --before_context=2 --after_context=1`
    Then STDOUT should contain:
      """
      Success: Made 2 replacements.
      """
    And STDOUT should contain:
      """
      fin_posts.post_content:{POST_ID}
      < バäz_1 [...] バäz_1
      > バäzzzz_1 [...] バäzzzz_1
      """
    And STDERR should be empty

    When I run `fin option set foobar '_bar1_ _bar1_12345678901234567890123456789012345678901234567890_bar1_ _bar1_1234567890123456789012345678901234567890'`
    And I run `fin search-replace '_bar1_' '_baz1_' fin_options --log`
    Then STDOUT should contain:
      """
      < _bar1_ _bar1_1234567890123456789012345678901234567890 [...] 1234567890123456789012345678901234567890_bar1_ _bar1_1234567890123456789012345678901234567890
      > _baz1_ _baz1_1234567890123456789012345678901234567890 [...] 1234567890123456789012345678901234567890_baz1_ _baz1_1234567890123456789012345678901234567890
      """
    And STDERR should be empty

    When I run `fin option get foobar`
    Then STDOUT should be:
      """
      _baz1_ _baz1_12345678901234567890123456789012345678901234567890_baz1_ _baz1_1234567890123456789012345678901234567890
      """

    When I run `fin search-replace '_baz1_' '_bar1_' fin_options --log --before_context=10 --after_context=10`
    Then STDOUT should contain:
      """
      < _baz1_ _baz1_1234567890 [...] 1234567890_baz1_ _baz1_1234567890
      > _bar1_ _bar1_1234567890 [...] 1234567890_bar1_ _bar1_1234567890
      """
    And STDERR should be empty

    When I run `fin option set foobar2 '12345678901234567890_bar2_1234567890_bar2_ _bar2_ _bar2_'`
    And I run `fin search-replace '_bar2_' '_baz2baz2_' fin_options --log --before_context=10 --after_context=10`
    Then STDOUT should contain:
      """
      < 1234567890_bar2_1234567890 [...] 1234567890_bar2_ _bar2_ _bar2_
      > 1234567890_baz2baz2_1234567890 [...] 1234567890_baz2baz2_ _baz2baz2_ _baz2baz2_
      """
    And STDERR should be empty

    When I run `fin option get foobar2`
    Then STDOUT should be:
      """
      12345678901234567890_baz2baz2_1234567890_baz2baz2_ _baz2baz2_ _baz2baz2_
      """

    When I run `fin search-replace '_baz2baz2_' '_barz2_' fin_options --log  --before_context=10 --after_context=4`
    Then STDOUT should contain:
      """
      < 1234567890_baz2baz2_1234 [...] 1234567890_baz2baz2_ _baz2baz2_ _baz2baz2_
      > 1234567890_barz2_1234 [...] 1234567890_barz2_ _barz2_ _barz2_
      """
    And STDERR should be empty

    When I run `fin option set foobar3 '_bar3 _bar3 _bar3 _bar3'`
    And I run `fin search-replace '_bar3' 'baz3' fin_options --log`
    Then STDOUT should contain:
      """
      < _bar3 _bar3 _bar3 _bar3
      > baz3 baz3 baz3 baz3
      """
    And STDERR should be empty

    When I run `fin option get foobar3`
    Then STDOUT should be:
      """
      baz3 baz3 baz3 baz3
      """

    When I run `fin search-replace 'baz3' 'baz\3' fin_options --dry-run --log`
    Then STDOUT should contain:
      """
      < baz3 baz3 baz3 baz3
      > baz\3 baz\3 baz\3 baz\3
      """
    And STDERR should be empty

  Scenario: Logging with regex replace
    Given a FIN install

    When I run `fin post create --post_title='Title_baz__boz_' --post_content='Content_baz_1234567890_bez_1234567890_biz_1234567890_boz_1234567890_buz_' --porcelain`
    Then save STDOUT as {POST_ID}

    When I run `fin search-replace '_b[aeiou]z_' '_bz_' fin_posts --regex --dry-run --log  --before_context=11 --after_context=11`
    Then STDOUT should contain:
      """
      Success: 2 replacements to be made.
      """
    And STDOUT should end with a table containing rows:
      | Table    | Column       | Replacements | Type |
      | fin_posts | post_content | 1            | PHP  |
      | fin_posts | post_title   | 1            | PHP  |

    And STDOUT should contain:
      """
      fin_posts.post_content:{POST_ID}
      < Content_baz_1234567890_bez_1234567890_biz_1234567890_boz_1234567890_buz_
      > Content_bz_1234567890_bz_1234567890_bz_1234567890_bz_1234567890_bz_
      """
    And STDOUT should contain:
      """
      fin_posts.post_title:{POST_ID}
      < Title_baz__boz_
      > Title_bz__bz_
      """
    And STDERR should be empty

    When I run `fin search-replace '_b([aeiou])z_' '_$1b\\1z_\0' fin_posts --regex --log --before_context=11 --after_context=11`
    Then STDOUT should contain:
      """
      Success: Made 2 replacements.
      """

    And STDOUT should contain:
      """
      fin_posts.post_content:{POST_ID}
      < Content_baz_1234567890_bez_1234567890_biz_1234567890_boz_1234567890_buz_
      > Content_ab\1z__baz_1234567890_eb\1z__bez_1234567890_ib\1z__biz_1234567890_ob\1z__boz_1234567890_ub\1z__buz_
      """
    And STDOUT should contain:
      """
      fin_posts.post_title:{POST_ID}
      < Title_baz__boz_
      > Title_ab\1z__baz__ob\1z__boz_
      """
    And STDERR should be empty

    When I run `fin post get {POST_ID} --field=title`
    Then STDOUT should be:
      """
      Title_ab\1z__baz__ob\1z__boz_
      """

    When I run `fin post get {POST_ID} --field=content`
    Then STDOUT should be:
      """
      Content_ab\1z__baz_1234567890_eb\1z__bez_1234567890_ib\1z__biz_1234567890_ob\1z__boz_1234567890_ub\1z__buz_
      """

  @require-mysql
  Scenario: Logging with prefixes and custom colors
    Given a FIN install
    And I run `fin option set blogdescription 'Just another FinPress site'`

    When I run `FIN_CLI_SEARCH_REPLACE_LOG_PREFIXES='- ,+ ' fin search-replace Just Yet --dry-run --log`
    Then STDOUT should contain:
      """
      - Just another FinPress site
      + Yet another FinPress site
      """
    And STDERR should be empty

    When I run `FIN_CLI_SEARCH_REPLACE_LOG_PREFIXES=',' fin search-replace Just Yet --dry-run --log`
    Then STDOUT should not contain:
      """
      < Just
      """
    And STDOUT should contain:
      """
      Just
      """
    And STDOUT should not contain:
      """
      > Yet
      """
    And STDOUT should contain:
      """
      Yet
      """
    And STDERR should be empty

    When I run `SHELL_PIPE=0 fin search-replace FinPress FIN --dry-run --log`
    Then STDOUT should strictly contain:
      """
      [34;1mfin_options.option_value:
      """
    And STDOUT should strictly contain:
      """
      [31;1m< [0mJust another [31;1mFinPress[0m site
      [32;1m> [0mJust another [32;1mFIN[0m site
      """
    And STDERR should be empty

    When I run `SHELL_PIPE=0 FIN_CLI_SEARCH_REPLACE_LOG_COLORS='%b,%r,%g' fin search-replace FinPress FIN --dry-run --log`
    Then STDOUT should strictly contain:
      """
      [34mfin_options.option_value:
      """
    And STDOUT should strictly contain:
      """
      [31m< [0mJust another [31mFinPress[0m site
      [32m> [0mJust another [32mFIN[0m site
      """
    And STDERR should be empty

    When I run `SHELL_PIPE=0 FIN_CLI_SEARCH_REPLACE_LOG_COLORS='%b,%r,%g' fin search-replace FinPress FIN --dry-run --log=replace.log`
    Then STDOUT should not contain:
      """
      fin_options.option_value
      """
    And the replace.log file should strictly contain:
      """
      [34mfin_options.option_value:
      """
    And the replace.log file should strictly contain:
      """
      [31m< [0mJust another [31mFinPress[0m site
      [32m> [0mJust another [32mFIN[0m site
      """
    And STDERR should be empty

    When I run `SHELL_PIPE=0 fin search-replace FinPress FIN --dry-run --log=replace.log`
    Then STDOUT should not contain:
      """
      fin_options.option_value
      """
    And the replace.log file should contain:
      """
      fin_options.option_value:
      """
    And the replace.log file should contain:
      """
      < Just another FinPress site
      > Just another FIN site
      """
    And STDERR should be empty

    When I run `SHELL_PIPE=0 FIN_CLI_SEARCH_REPLACE_LOG_COLORS=',,' fin search-replace FinPress FIN --dry-run --log`
    Then STDOUT should contain:
      """
      fin_options.option_value:
      """
    And STDOUT should contain:
      """
      < Just another FinPress site
      > Just another FIN site
      """
    And STDERR should be empty

  # Regression test for https://github.com/fin-cli/search-replace-command/issues/58
  @require-mysql
  Scenario: The parameters --regex and --all-tables-with-prefix produce valid SQL
    Given a FIN install
    And a test_db.sql file:
      """
      CREATE TABLE `fin_123_test` (
      `name` varchar(50),
      `value` varchar(5000),
      `created_at` datetime NOT NULL,
      `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (`name`)
      ) ENGINE=InnoDB;
      INSERT INTO `fin_123_test` VALUES ('test_val','fin_123_test_value_X','2016-11-15 14:41:33','2016-11-15 21:41:33');
      INSERT INTO `fin_123_test` VALUES ('123.','fin_123_test_value_X','2016-11-15 14:41:33','2016-11-15 21:41:33');
      INSERT INTO `fin_123_test` VALUES ('quote\'quote','fin_123_test_value_X','2016-11-15 14:41:33','2016-11-15 21:41:33');
      INSERT INTO `fin_123_test` VALUES ('0','fin_123_test_value_X','2016-11-15 14:41:33','2016-11-15 21:41:33');
      INSERT INTO `fin_123_test` VALUES ('','fin_123_test_value_X','2016-11-15 14:41:33','2016-11-15 21:41:33');
      INSERT INTO `fin_123_test` VALUES ('18446744073709551616','fin_123_test_value_X','2016-11-15 14:41:33','2016-11-15 21:41:33');
      INSERT INTO `fin_123_test` VALUES ('-18446744073709551615','fin_123_test_value_X','2016-11-15 14:41:33','2016-11-15 21:41:33');
      INSERT INTO `fin_123_test` VALUES ('123456789012345678801234567890','fin_123_test_value_X','2016-11-15 14:41:33','2016-11-15 21:41:33');

      CREATE TABLE `fin_123_test2` (`bigint_unsigned_key` BIGINT UNSIGNED NOT NULL, `value` VARCHAR(255), PRIMARY KEY (`bigint_unsigned_key`) );
      INSERT INTO `fin_123_test2` VALUES ('18446744073709551615','fin_123_test2_value_X');

      CREATE TABLE `fin_123_test3` (`bigint_signed_key` BIGINT SIGNED NOT NULL, `value` VARCHAR(255), PRIMARY KEY (`bigint_signed_key`) );
      INSERT INTO `fin_123_test3` VALUES ('-9223372036854775808','fin_123_test3_value_X');
      """
    And I run `fin db query "SOURCE test_db.sql;"`

    When I run `fin search-replace --dry-run --regex 'mytestdomain.com\/' 'mytestdomain2.com/' --all-tables-with-prefix --skip-columns=guid,domain`
    Then STDOUT should contain:
      """
      Success: 0 replacements to be made.
      """

    When I run `fin search-replace --dry-run --regex 'fin_123_test_value_X' 'fin_123_test_value_Y' --all-tables-with-prefix`
    Then STDOUT should contain:
      """
      Success: 8 replacements to be made.
      """

    When I run `fin search-replace --dry-run --regex 'fin_123_test2_value_X' 'fin_123_test2_value_Y' --all-tables-with-prefix`
    Then STDOUT should contain:
      """
      Success: 1 replacement to be made.
      """

    When I run `fin search-replace --dry-run --regex 'fin_123_test3_value_X' 'fin_123_test3_value_Y' --all-tables-with-prefix`
    Then STDOUT should contain:
      """
      Success: 1 replacement to be made.
      """

  # Regression test for https://github.com/fin-cli/search-replace-command/issues/68
  @require-mysql
  Scenario: Incomplete classes are handled gracefully during (un)serialization

    Given a FIN install
    And I run `fin option add cereal_isation 'a:1:{i:0;O:10:"CornFlakes":0:{}}'`

    When I try `fin search-replace CornFlakes Smacks`
    Then STDERR should contain:
      """
      Warning: Skipping an uninitialized class "CornFlakes", replacements might not be complete.
      """
    And STDOUT should contain:
      """
      Success: Made 0 replacements.
      """

    When I run `fin option get cereal_isation`
    Then STDOUT should contain:
      """
      a:1:{i:0;O:10:"CornFlakes":0:{}}
      """

  @require-mysql @less-than-php-8.0
  Scenario: Warn and ignore type-hinted objects that have some error in deserialization (PHP < 8.0)
    Given a FIN install
    And I run `fin db query "INSERT INTO fin_options (option_name,option_value) VALUES ('cereal_isation','O:13:\"mysqli_result\":5:{s:13:\"current_field\";N;s:11:\"field_count\";N;s:7:\"lengths\";N;s:8:\"num_rows\";N;s:4:\"type\";N;}')"`
    And I run `fin db query "INSERT INTO fin_options (option_name,option_value) VALUES ('cereal_isation_2','O:8:\"mysqli_result\":5:{s:13:\"current_field\";i:1;s:11:\"field_count\";i:2;s:7:\"lengths\";a:1:{i:0;s:4:\"blah\";}s:8:\"num_rows\";i:1;s:4:\"type\";i:2;}')"`

    When I try `fin search-replace mysqli_result stdClass`
    Then STDERR should contain:
      """
      Warning: FIN_CLI\SearchReplacer::run_recursively(): Couldn't fetch mysqli_result
      """
    And STDOUT should contain:
      """
      Success: Made 1 replacement.
      """

    When I run `fin db query "SELECT option_value from fin_options where option_name='cereal_isation_2'" --skip-column-names`
    Then STDOUT should contain:
      """
      O:8:"stdClass":5:{s:13:"current_field";i:1;s:11:"field_count";i:2;s:7:"lengths";a:1:{i:0;s:4:"blah";}s:8:"num_rows";i:1;s:4:"type";i:2;}
      """
    And save STDOUT as {SERIALIZED_RESULT}
    And a test_php.php file:
      """
      <?php print_r(unserialize('{SERIALIZED_RESULT}'));
      """

    When I try `fin eval-file test_php.php`
    Then STDOUT should contain:
      """
      stdClass Object
      """
    And STDOUT should contain:
      """
      [current_field] => 1
      """
    And STDOUT should contain:
      """
      [field_count] => 2
      """

  @require-mysql @require-php-8.0 @less-than-php-8.1
  Scenario: Warn and ignore type-hinted objects that have some error in deserialization (PHP 8.0)
    Given a FIN install
    And I run `fin db query "INSERT INTO fin_options (option_name,option_value) VALUES ('cereal_isation','O:13:\"mysqli_result\":5:{s:13:\"current_field\";N;s:11:\"field_count\";N;s:7:\"lengths\";N;s:8:\"num_rows\";N;s:4:\"type\";N;}')"`
    And I run `fin db query "INSERT INTO fin_options (option_name,option_value) VALUES ('cereal_isation_2','O:8:\"mysqli_result\":5:{s:13:\"current_field\";i:1;s:11:\"field_count\";i:2;s:7:\"lengths\";a:1:{i:0;s:4:\"blah\";}s:8:\"num_rows\";i:1;s:4:\"type\";i:2;}')"`

    When I try `fin search-replace mysqli_result stdClass`
    Then STDERR should contain:
      """
      Warning: Skipping an inconvertible serialized object of type "mysqli_result", replacements might not be complete. Reason: mysqli_result object is already closed.
      """
    And STDOUT should contain:
      """
      Success: Made 1 replacement.
      """

    When I run `fin db query "SELECT option_value from fin_options where option_name='cereal_isation_2'" --skip-column-names`
    Then STDOUT should contain:
      """
      O:8:"stdClass":5:{s:13:"current_field";i:1;s:11:"field_count";i:2;s:7:"lengths";a:1:{i:0;s:4:"blah";}s:8:"num_rows";i:1;s:4:"type";i:2;}
      """
    And save STDOUT as {SERIALIZED_RESULT}
    And a test_php.php file:
      """
      <?php print_r(unserialize('{SERIALIZED_RESULT}'));
      """

    When I try `fin eval-file test_php.php`
    Then STDOUT should contain:
      """
      stdClass Object
      """
    And STDOUT should contain:
      """
      [current_field] => 1
      """
    And STDOUT should contain:
      """
      [field_count] => 2
      """

  @require-mysql @require-php-8.1
  Scenario: Warn and ignore type-hinted objects that have some error in deserialization (PHP 8.1+)
    Given a FIN install
    And I run `fin db query "INSERT INTO fin_options (option_name,option_value) VALUES ('cereal_isation','O:13:\"mysqli_result\":5:{s:13:\"current_field\";N;s:11:\"field_count\";N;s:7:\"lengths\";N;s:8:\"num_rows\";N;s:4:\"type\";N;}')"`
    And I run `fin db query "INSERT INTO fin_options (option_name,option_value) VALUES ('cereal_isation_2','O:8:\"mysqli_result\":5:{s:13:\"current_field\";i:1;s:11:\"field_count\";i:2;s:7:\"lengths\";a:1:{i:0;s:4:\"blah\";}s:8:\"num_rows\";i:1;s:4:\"type\";i:2;}')"`

    When I try `fin search-replace mysqli_result stdClass`
    Then STDERR should contain:
      """
      Warning: Skipping an inconvertible serialized object: "O:13:"mysqli_result":5:{s:13:"current_field";N;s:11:"field_count";N;s:7:"lengths";N;s:8:"num_rows";N;s:4:"type";N;}", replacements might not be complete. Reason: Cannot assign null to property mysqli_result::$current_field of type int.
      """
    And STDOUT should contain:
      """
      Success: Made 1 replacement.
      """

    When I run `fin db query "SELECT option_value from fin_options where option_name='cereal_isation_2'" --skip-column-names`
    Then STDOUT should contain:
      """
      O:8:"stdClass":5:{s:13:"current_field";i:1;s:11:"field_count";i:2;s:7:"lengths";a:1:{i:0;s:4:"blah";}s:8:"num_rows";i:1;s:4:"type";i:2;}
      """
    And save STDOUT as {SERIALIZED_RESULT}
    And a test_php.php file:
      """
      <?php print_r(unserialize('{SERIALIZED_RESULT}'));
      """

    When I try `fin eval-file test_php.php`
    Then STDOUT should contain:
      """
      stdClass Object
      """
    And STDOUT should contain:
      """
      [current_field] => 1
      """
    And STDOUT should contain:
      """
      [field_count] => 2
      """

  Scenario: Regex search/replace with `--regex-limit=1` option
    Given a FIN install
    And I run `fin post create --post_content="I have a pen, I have an apple. Pen, pine-apple, apple-pen."`

    When I run `fin search-replace --regex "ap{2}le" "orange" --regex-limit=1 --log`
    Then STDOUT should contain:
      """
      I have a pen, I have an orange. Pen, pine-apple, apple-pen.
      """

  Scenario: Regex search/replace with `--regex-limit=2` option
    Given a FIN install
    And I run `fin post create --post_content="I have a pen, I have an apple. Pen, pine-apple, apple-pen."`

    When I run `fin search-replace --regex "ap{2}le" "orange" --regex-limit=2 --log`
    Then STDOUT should contain:
      """
      I have a pen, I have an orange. Pen, pine-orange, apple-pen.
      """

  Scenario: Regex search/replace with incorrect or default `--regex-limit`
    Given a FIN install
    When I try `fin search-replace '(Hello)\s(world)' '$2, $1' --regex --regex-limit=asdf`
    Then STDERR should be:
      """
      Error: `--regex-limit` expects a non-zero positive integer or -1.
      """
    When I try `fin search-replace '(Hello)\s(world)' '$2, $1' --regex --regex-limit=0`
    Then STDERR should be:
      """
      Error: `--regex-limit` expects a non-zero positive integer or -1.
      """
    When I try `fin search-replace '(Hello)\s(world)' '$2, $1' --regex --regex-limit=-2`
    Then STDERR should be:
      """
      Error: `--regex-limit` expects a non-zero positive integer or -1.
      """
    When I run `fin search-replace '(Hello)\s(world)' '$2, $1' --regex --regex-limit=-1`
    Then STDOUT should contain:
      """
      Success:
      """

  @require-mysql
  Scenario: Chunking a precise search and replace works without skipping lines
    Given a FIN install
    And a create_sql_file.sh file:
      """
      #!/bin/bash
      echo "CREATE TABLE \`fin_123_test\` (\`key\` INT(5) UNSIGNED NOT NULL AUTO_INCREMENT, \`text\` TEXT, PRIMARY KEY (\`key\`) );" > test_db.sql
      echo "INSERT INTO \`fin_123_test\` (\`text\`) VALUES" >> test_db.sql
      index=1
      while [[ $index -le 199 ]];
      do
      echo "('abc'),('abc'),('abc'),('abc'),('abc'),('abc'),('abc'),('abc'),('abc'),('abc')," >> test_db.sql
      index=`expr $index + 1`
      done
      echo "('abc'),('abc'),('abc'),('abc'),('abc'),('abc'),('abc'),('abc'),('abc'),('abc');" >> test_db.sql
      echo "CREATE TABLE \`fin_123_test_multikey\` (\`key1\` INT(5) UNSIGNED NOT NULL AUTO_INCREMENT, \`key2\` INT(5) UNSIGNED NOT NULL, \`key3\` INT(5) UNSIGNED NOT NULL, \`text\` TEXT, PRIMARY KEY (\`key1\`,\`key2\`,\`key3\`) );" >> test_db.sql
      echo "INSERT INTO \`fin_123_test_multikey\` (\`key2\`,\`key3\`,\`text\`) VALUES" >> test_db.sql
      index=1
      while [[ $index -le 204 ]];
      do
      echo "(0,0,'abc'),(1,1,'abc'),(2,2,'abc'),(3,3,'abc'),(4,4,'abc'),(5,0,'abc'),(6,1,'abc'),(7,2,'abc'),(8,3,'abc'),(9,4,'abc')," >> test_db.sql
      index=`expr $index + 1`
      done
      echo "(0,0,'abc'),(1,1,'abc'),(2,2,'abc'),(3,3,'abc'),(4,4,'abc'),(5,0,'abc'),(6,1,'abc'),(7,2,'abc'),(8,3,'abc'),(9,4,'abc');" >> test_db.sql
      """
    And I run `bash create_sql_file.sh`
    And I run `fin db query "SOURCE test_db.sql;"`

    When I run `fin search-replace --dry-run 'abc' 'def' --all-tables-with-prefix --skip-columns=guid,domain --precise`
    Then STDOUT should contain:
      """
      Success: 4050 replacements to be made.
      """

    When I run `fin search-replace 'abc' 'def' --all-tables-with-prefix --skip-columns=guid,domain --precise`
    Then STDOUT should contain:
      """
      Success: Made 4050 replacements.
      """

    When I run `fin search-replace --dry-run 'abc' 'def' --all-tables-with-prefix --skip-columns=guid,domain --precise`
    Then STDOUT should contain:
      """
      Success: 0 replacements to be made.
      """

    When I run `fin search-replace 'abc' 'def' --all-tables-with-prefix --skip-columns=guid,domain --precise`
    Then STDOUT should contain:
      """
      Success: Made 0 replacements.
      """

  @require-mysql
  Scenario: Chunking a regex search and replace works without skipping lines
    Given a FIN install
    And a create_sql_file.sh file:
      """
      #!/bin/bash
      echo "CREATE TABLE \`fin_123_test\` (\`key\` INT(5) UNSIGNED NOT NULL AUTO_INCREMENT, \`text\` TEXT, PRIMARY KEY (\`key\`) );" > test_db.sql
      echo "INSERT INTO \`fin_123_test\` (\`text\`) VALUES" >> test_db.sql
      index=1
      while [[ $index -le 199 ]];
      do
      echo "('abc'),('abc'),('abc'),('abc'),('abc'),('abc'),('abc'),('abc'),('abc'),('abc')," >> test_db.sql
      index=`expr $index + 1`
      done
      echo "('abc'),('abc'),('abc'),('abc'),('abc'),('abc'),('abc'),('abc'),('abc'),('abc');" >> test_db.sql
      echo "CREATE TABLE \`fin_123_test_multikey\` (\`key1\` INT(5) UNSIGNED NOT NULL AUTO_INCREMENT, \`key2\` INT(5) UNSIGNED NOT NULL, \`key3\` INT(5) UNSIGNED NOT NULL, \`text\` TEXT, PRIMARY KEY (\`key1\`,\`key2\`,\`key3\`) );" >> test_db.sql
      echo "INSERT INTO \`fin_123_test_multikey\` (\`key2\`,\`key3\`,\`text\`) VALUES" >> test_db.sql
      index=1
      while [[ $index -le 204 ]];
      do
      echo "(0,0,'abc'),(1,1,'abc'),(2,2,'abc'),(3,3,'abc'),(4,4,'abc'),(5,0,'abc'),(6,1,'abc'),(7,2,'abc'),(8,3,'abc'),(9,4,'abc')," >> test_db.sql
      index=`expr $index + 1`
      done
      echo "(0,0,'abc'),(1,1,'abc'),(2,2,'abc'),(3,3,'abc'),(4,4,'abc'),(5,0,'abc'),(6,1,'abc'),(7,2,'abc'),(8,3,'abc'),(9,4,'abc');" >> test_db.sql
      """
    And I run `bash create_sql_file.sh`
    And I run `fin db query "SOURCE test_db.sql;"`

    When I run `fin search-replace --dry-run 'abc' 'def' --all-tables-with-prefix --skip-columns=guid,domain --regex`
    Then STDOUT should contain:
      """
      Success: 4050 replacements to be made.
      """

    When I run `fin search-replace 'abc' 'def' --all-tables-with-prefix --skip-columns=guid,domain --regex`
    Then STDOUT should contain:
      """
      Success: Made 4050 replacements.
      """

    When I run `fin search-replace --dry-run 'abc' 'def' --all-tables-with-prefix --skip-columns=guid,domain --regex`
    Then STDOUT should contain:
      """
      Success: 0 replacements to be made.
      """

    When I run `fin search-replace 'abc' 'def' --all-tables-with-prefix --skip-columns=guid,domain --regex`
    Then STDOUT should contain:
      """
      Success: Made 0 replacements.
      """
