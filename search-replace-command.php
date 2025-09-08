<?php

if ( ! class_exists( 'FP_CLI' ) ) {
	return;
}

$fpcli_search_replace_autoloader = __DIR__ . '/vendor/autoload.php';
if ( file_exists( $fpcli_search_replace_autoloader ) ) {
	require_once $fpcli_search_replace_autoloader;
}

FP_CLI::add_command( 'search-replace', 'Search_Replace_Command' );
