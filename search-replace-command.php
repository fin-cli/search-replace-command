<?php

if ( ! class_exists( 'FIN_CLI' ) ) {
	return;
}

$fincli_search_replace_autoloader = __DIR__ . '/vendor/autoload.php';
if ( file_exists( $fincli_search_replace_autoloader ) ) {
	require_once $fincli_search_replace_autoloader;
}

FIN_CLI::add_command( 'search-replace', 'Search_Replace_Command' );
