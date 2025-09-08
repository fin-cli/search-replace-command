Feature: Search / replace with file export

  @require-mysql
  Scenario: Search / replace export to STDOUT
    Given a FP install
    And I run `echo ' '`
    And save STDOUT as {SPACE}

    When I run `fp search-replace example.com example.net --export`
    Then STDOUT should contain:
      """
      DROP TABLE IF EXISTS `fp_commentmeta`;
      CREATE TABLE `fp_commentmeta`
      """
    And STDOUT should contain:
      """
      'siteurl', 'https://example.net',
      """

    When I run `fp option get home`
    Then STDOUT should be:
      """
      https://example.com
      """

    When I run `fp search-replace example.com example.net --skip-tables=fp_options --export`
    Then STDOUT should not contain:
      """
      INSERT INTO `fp_options`
      """

    When I run `fp search-replace example.com example.net --skip-tables=fp_opt\?ons,fp_post\* --export`
    Then STDOUT should not contain:
      """
      fp_posts
      """
    And STDOUT should not contain:
      """
      fp_postmeta
      """
    And STDOUT should not contain:
      """
      fp_options
      """
    And STDOUT should contain:
      """
      fp_users
      """

    When I run `fp search-replace example.com example.net --skip-columns=option_value --export`
    Then STDOUT should contain:
      """
      INSERT INTO `fp_options` (`option_id`, `option_name`, `option_value`, `autoload`) VALUES{SPACE}
      """
    And STDOUT should contain:
      """
    'siteurl', 'https://example.com'
      """

    When I run `fp search-replace example.com example.net --skip-columns=option_value --export --export_insert_size=1`
    Then STDOUT should contain:
      """
      'siteurl', 'https://example.com'
      """
    And STDOUT should contain:
      """
    INSERT INTO `fp_options` (`option_id`, `option_name`, `option_value`, `autoload`) VALUES{SPACE}
      """

    When I run `fp search-replace foo bar --export | tail -n 1`
    Then STDOUT should not contain:
      """
      Success: Made
      """

    When I run `fp search-replace example.com example.net --export > finpress.sql`
    And I run `fp db import finpress.sql`
    Then STDOUT should not be empty

    When I run `fp option get home`
    Then STDOUT should be:
      """
      https://example.net
      """

  @require-mysql
  Scenario: Search / replace export to file
    Given a FP install
    And I run `fp post generate --count=100`
    And I run `fp option add example_url https://example.com`

    When I run `fp search-replace example.com example.net --export=finpress.sql`
    Then STDOUT should contain:
      """
      Success: Made
      """
    # Skip exact number as it changes in trunk due to https://core.trac.finpress.org/changeset/42981
    And STDOUT should contain:
      """
      replacements and exported to finpress.sql
      """
    And STDOUT should be a table containing rows:
      | Table         | Column       | Replacements | Type |
      | fp_options    | option_value | 6            | PHP  |

    When I run `fp option get home`
    Then STDOUT should be:
      """
      https://example.com
      """

    When I run `fp site empty --yes`
    And I run `fp post list --format=count`
    Then STDOUT should be:
      """
      0
      """

    When I run `fp db import finpress.sql`
    Then STDOUT should not be empty

    When I run `fp option get home`
    Then STDOUT should be:
      """
      https://example.net
      """

    When I run `fp option get example_url`
    Then STDOUT should be:
      """
      https://example.net
      """

    When I run `fp post list --format=count`
    Then STDOUT should be:
      """
      101
      """

  @require-mysql
  Scenario: Search / replace export to file with verbosity
    Given a FP install

    When I run `fp search-replace example.com example.net --export=finpress.sql --verbose`
    Then STDOUT should contain:
      """
      Checking: fp_posts
      """
    And STDOUT should contain:
      """
      Checking: fp_options
      """

  Scenario: Search / replace export with dry-run
    Given a FP install

    When I try `fp search-replace example.com example.net --export --dry-run`
    Then STDERR should be:
      """
      Error: You cannot supply --dry-run and --export at the same time.
      """

  @require-mysql
  Scenario: Search / replace shouldn't affect primary key
    Given a FP install
    And I run `fp post create --post_title=foo --porcelain`
    Then save STDOUT as {POST_ID}

    When I run `fp option update {POST_ID} foo`
    And I run `fp option get {POST_ID}`
    Then STDOUT should be:
      """
      foo
      """

    When I run `fp search-replace {POST_ID} 99999999 --export=finpress.sql`
    And I run `fp db import finpress.sql`
    Then STDOUT should not be empty

    When I run `fp post get {POST_ID} --field=title`
    Then STDOUT should be:
      """
      foo
      """

    When I try `fp option get {POST_ID}`
    Then STDOUT should be empty

    When I run `fp option get 99999999`
    Then STDOUT should be:
      """
      foo
      """

  Scenario: Search / replace export invalid file
    Given a FP install

    When I try `fp search-replace example.com example.net --export=foo/bar.sql`
    Then STDERR should contain:
      """
      Error: Unable to open export file "foo/bar.sql" for writing:
      """

  @require-mysql
  Scenario: Search / replace specific table
    Given a FP install

    When I run `fp post create --post_title=foo --porcelain`
    Then save STDOUT as {POST_ID}

    When I run `fp option update bar foo`
    Then STDOUT should not be empty

    When I run `fp search-replace foo burrito fp_posts --export=finpress.sql --verbose`
    Then STDOUT should contain:
      """
      Checking: fp_posts
      """
    And STDOUT should contain:
      """
      Success: Made 1 replacement and exported to finpress.sql.
      """

    When I run `fp db import finpress.sql`
    Then STDOUT should not be empty

    When I run `fp post get {POST_ID} --field=title`
    Then STDOUT should be:
      """
      burrito
      """

    When I run `fp option get bar`
    Then STDOUT should be:
      """
      foo
      """

  @require-mysql
  Scenario: Search / replace export should cater for field/table names that use reserved words or unusual characters
    Given a FP install
    # Unlike search-replace.features version, don't use `back``tick` column name as FP_CLI\Iterators\Table::build_fields() can't handle it.
    And a esc_sql_ident.sql file:
      """
      CREATE TABLE `TABLE` (`KEY` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT, `VALUES` TEXT, `single'double"quote` TEXT, PRIMARY KEY (`KEY`) );
      INSERT INTO `TABLE` (`VALUES`, `single'double"quote`) VALUES ('v"vvvv_v1', 'v"vvvv_v1' );
      INSERT INTO `TABLE` (`VALUES`, `single'double"quote`) VALUES ('v"vvvv_v2', 'v"vvvv_v2' );
      """

    When I run `fp db query "SOURCE esc_sql_ident.sql;"`
    Then STDERR should be empty

    When I run `fp search-replace 'v"vvvv_v' 'w"wwww_w' TABLE --export --all-tables`
    Then STDOUT should contain:
      """
      INSERT INTO `TABLE` (`KEY`, `VALUES`, `single'double"quote`) VALUES
      """
    And STDOUT should contain:
      """
      ('1', 'w\"wwww_w1', 'w\"wwww_w1')
      """
    And STDOUT should contain:
      """
      ('2', 'w\"wwww_w2', 'w\"wwww_w2')
      """
    And STDERR should be empty

    When I run `fp search-replace 'v"vvvv_v2' 'w"wwww_w2' TABLE --export --regex --all-tables`
    Then STDOUT should contain:
      """
      INSERT INTO `TABLE` (`KEY`, `VALUES`, `single'double"quote`) VALUES
      """
    And STDOUT should contain:
      """
      ('1', 'v\"vvvv_v1', 'v\"vvvv_v1')
      """
    And STDOUT should contain:
      """
      ('2', 'w\"wwww_w2', 'w\"wwww_w2')
      """
    And STDERR should be empty

  @require-mysql
  Scenario: Suppress report or only report changes on export to file
    Given a FP install

    When I run `fp option set foo baz`
    And I run `fp option get foo`
    Then STDOUT should be:
      """
      baz
      """

    When I run `fp post create --post_title=baz --porcelain`
    Then save STDOUT as {POST_ID}

    When I run `fp post meta add {POST_ID} foo baz`
    Then STDOUT should not be empty

    When I run `fp search-replace baz bar --export=finpress.sql`
    Then STDOUT should contain:
      """
      Success: Made 3 replacements and exported to finpress.sql.
      """
    And STDOUT should be a table containing rows:
    | Table          | Column       | Replacements | Type |
    | fp_commentmeta | meta_id      | 0            | PHP  |
    | fp_options     | option_value | 1            | PHP  |
    | fp_postmeta    | meta_value   | 1            | PHP  |
    | fp_posts       | post_title   | 1            | PHP  |
    | fp_users       | display_name | 0            | PHP  |
    And STDERR should be empty

    When I run `fp search-replace baz bar --report --export=finpress.sql`
    Then STDOUT should contain:
      """
      Success: Made 3 replacements and exported to finpress.sql.
      """
    And STDOUT should be a table containing rows:
    | Table          | Column       | Replacements | Type |
    | fp_commentmeta | meta_id      | 0            | PHP  |
    | fp_options     | option_value | 1            | PHP  |
    | fp_postmeta    | meta_value   | 1            | PHP  |
    | fp_posts       | post_title   | 1            | PHP  |
    | fp_users       | display_name | 0            | PHP  |
    And STDERR should be empty

    When I run `fp search-replace baz bar --no-report --export=finpress.sql`
    Then STDOUT should contain:
      """
      Success: Made 3 replacements and exported to finpress.sql.
      """
    And STDOUT should not contain:
      """
      Table	Column	Replacements	Type
      """
    And STDOUT should not contain:
      """
      fp_commentmeta	meta_id	0	PHP
      """
    And STDOUT should not contain:
      """
      fp_options	option_value	1	PHP
      """
    And STDERR should be empty

    When I run `fp search-replace baz bar --no-report-changed-only --export=finpress.sql`
    Then STDOUT should contain:
      """
      Success: Made 3 replacements and exported to finpress.sql.
      """
    And STDOUT should be a table containing rows:
    | Table          | Column       | Replacements | Type |
    | fp_commentmeta | meta_id      | 0            | PHP  |
    | fp_options     | option_value | 1            | PHP  |
    | fp_postmeta    | meta_value   | 1            | PHP  |
    | fp_posts       | post_title   | 1            | PHP  |
    | fp_users       | display_name | 0            | PHP  |
    And STDERR should be empty

    When I run `fp search-replace baz bar --report-changed-only --export=finpress.sql`
    Then STDOUT should contain:
      """
      Success: Made 3 replacements and exported to finpress.sql.
      """
    And STDOUT should end with a table containing rows:
    | Table          | Column       | Replacements | Type |
    | fp_options     | option_value | 1            | PHP  |
    | fp_postmeta    | meta_value   | 1            | PHP  |
    | fp_posts       | post_title   | 1            | PHP  |
    And STDOUT should not contain:
      """
      fp_commentmeta	meta_id	0	PHP
      """
    And STDOUT should not contain:
      """
      fp_users	display_name	0	PHP
      """
    And STDERR should be empty

  @require-mysql
  Scenario: Search / replace should remove placeholder escape on export
    Given a FP install
    And I run `fp post create --post_title=test-remove-placeholder-escape% --porcelain`
    Then save STDOUT as {POST_ID}

    When I run `fp search-replace baz bar --export | grep test-remove-placeholder-escape`
    Then STDOUT should contain:
      """
      'test-remove-placeholder-escape%'
      """
    And STDOUT should not contain:
      """
      'test-remove-placeholder-escape{'
      """

  @require-mysql
  Scenario: NULLs exported as NULL and not null string
    Given a FP install
    And I run `fp db query "INSERT INTO fp_postmeta VALUES (9999, 9999, NULL, 'foo')"`

    When I run `fp search-replace bar replaced fp_postmeta --export`
    Then STDOUT should contain:
      """
     ('9999', '9999', NULL, 'foo')
      """
    And STDOUT should not contain:
      """
     ('9999', '9999', '', 'foo')
      """
