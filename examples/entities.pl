use FindBin;
use lib "$FindBin::Bin/../lib";
use Mojo::Base -strict;

# "She's built like a steakhouse, but she handles like a bistro!"
use Mojo::ByteStream 'b';
use Mojo::UserAgent;

# Extract named character references from HTML5 spec
my $tx
  = Mojo::UserAgent->new->get('http://dev.w3.org/html5/spec/single-page.html');
b($_->at('td > code')->text . $_->children('td')->[1]->text)->trim->say
  for $tx->res->dom('#named-character-references-table tbody > tr')->each;

1;
