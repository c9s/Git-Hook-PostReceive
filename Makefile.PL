use inc::Module::Install;
name 'Git-Hook-PostReceive';
all_from 'lib/Git/Hook/PostReceive.pm';

readme_markdown_from_pod 'lib/Git/Hook/PostReceive.pm';

requires 'Moose';
requires 'methods';
requires 'File::Basename';
requires 'invoker';
requires 'Cwd';
requires 'DateTime::Format::DateParse';

tests 't/*.t';
# author_tests 'xt';
# test_requires 'Test::More';
# auto_set_repository;
auto_include;
WriteAll;
