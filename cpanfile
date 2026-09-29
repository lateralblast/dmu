# Perl dependencies for dmu.pl
# Install with: cpanm --installdeps .

# Core modules (ship with Perl, listed for completeness)
requires 'perl', '5.006';
requires 'Getopt::Std';
requires 'File::Basename';
requires 'Cwd';

# Optional: used to read files without shelling out to cat.
# dmu.pl falls back to cat when it is not installed.
recommends 'File::Slurp';
