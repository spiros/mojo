package Mojolicious::Plugin::DefaultHelpers;
use Mojo::Base 'Mojolicious::Plugin';

use Data::Dumper ();
use Mojo::ByteStream;

# "You're watching Futurama,
#  the show that doesn't condone the cool crime of robbery."
sub register {
  my ($self, $app) = @_;

  # Controller alias helpers
  for my $name (qw(app flash param stash session url_for)) {
    $app->helper($name => sub { shift->$name(@_) });
  }

  # Stash key shortcuts
  for my $name (qw(extends layout title)) {
    $app->helper(
      $name => sub {
        my $self  = shift;
        my $stash = $self->stash;
        $stash->{$name} = shift if @_;
        $self->stash(@_) if @_;
        return $stash->{$name};
      }
    );
  }

  # Add "config" helper
  $app->helper(config => sub { shift->app->config(@_) });

  # Add "content" helper
  $app->helper(content => \&_content);

  # Add "content_for" helper
  $app->helper(content_for => \&_content_for);

  # Add "current_route" helper
  $app->helper(current_route => \&_current_route);

  # Add "dumper" helper
  $app->helper(dumper => \&_dumper);

  # Add "include" helper
  $app->helper(include => \&_include);

  # Add "memorize" helper
  my %mem;
  $app->helper(
    memorize => sub {
      my $self = shift;
      return '' unless ref(my $cb = pop) eq 'CODE';
      my ($name, $args)
        = ref $_[0] eq 'HASH' ? (undef, shift) : (shift, shift || {});

      # Default name
      $name ||= join '', map { $_ || '' } (caller(1))[0 .. 3];

      # Expire old results
      my $expires = $args->{expires} || 0;
      delete $mem{$name}
        if exists $mem{$name} && $expires > 0 && $mem{$name}{expires} < time;

      # Memorized result
      return $mem{$name}{content} if exists $mem{$name};

      # Memorize new result
      $mem{$name}{expires} = $expires;
      return $mem{$name}{content} = $cb->();
    }
  );

  # DEPRECATED in Rainbow!
  $app->helper(
    render_content => sub {
      warn "Mojolicious::Controller->render_content is DEPRECATED!\n";
      shift->content(@_);
    }
  );

  # Add "url_with" helper
  $app->helper(url_with => \&_url_with);
}

sub _content {
  my $self    = shift;
  my $name    = shift || 'content';
  my $content = pop;

  # Set
  my $c = $self->stash->{'mojo.content'} ||= {};
  if (defined $content) {

    # Reset with multiple values
    if (@_) {
      $c->{$name}
        = join('', map({ref $_ eq 'CODE' ? $_->() : $_} @_, $content));
    }

    # First come
    else { $c->{$name} ||= ref $content eq 'CODE' ? $content->() : $content }
  }

  # Get
  return Mojo::ByteStream->new($c->{$name} // '');
}

sub _content_for {
  my ($self, $name) = (shift, shift);
  _content($self, $name, _content($self, $name), @_);
}

sub _current_route {
  return '' unless my $endpoint = shift->match->endpoint;
  return $endpoint->name unless @_;
  return $endpoint->name eq shift;
}

sub _dumper { shift; Data::Dumper->new([@_])->Indent(1)->Terse(1)->Dump }

sub _include {
  my $self     = shift;
  my $template = @_ % 2 ? shift : undef;
  my $args     = {@_};
  $args->{template} = $template if defined $template;

  # "layout" and "extends" can't be localized
  my $layout  = delete $args->{layout};
  my $extends = delete $args->{extends};

  # Localize arguments
  my @keys = keys %$args;
  local @{$self->stash}{@keys} = @{$args}{@keys};

  return $self->render_partial(layout => $layout, extend => $extends);
}

sub _url_with {
  my $self = shift;
  return $self->url_for(@_)->query($self->req->url->query->clone);
}

1;

=head1 NAME

Mojolicious::Plugin::DefaultHelpers - Default helpers plugin

=head1 SYNOPSIS

  # Mojolicious
  $self->plugin('DefaultHelpers');

  # Mojolicious::Lite
  plugin 'DefaultHelpers';

=head1 DESCRIPTION

L<Mojolicious::Plugin::DefaultHelpers> is a collection of renderer helpers for
L<Mojolicious>.

This is a core plugin, that means it is always enabled and its code a good
example for learning to build new plugins, you're welcome to fork it.

=head1 HELPERS

L<Mojolicious::Plugin::DefaultHelpers> implements the following helpers.

=head2 C<app>

  %= app->secret

Alias for L<Mojolicious::Controller/"app">.

=head2 C<config>

  %= config 'something'

Alias for L<Mojo/"config">.

=head2 C<content>

  %= content foo => begin
    test
  % end
  %= content bar => 'Hello World!'
  %= content 'foo'
  %= content 'bar'
  %= content

Store partial rendered content and retrieve it.

=head2 C<content_for>

  % content_for foo => begin
    test
  % end
  %= content_for 'foo'

Append content to named buffer and retrieve it.

  % content_for message => begin
    Hello
  % end
  % content_for message => begin
    world!
  % end
  %= content_for 'message'

=head2 C<current_route>

  % if (current_route 'login') {
    Welcome to Mojolicious!
  % }
  %= current_route

Check or get name of current route.

=head2 C<dumper>

  %= dumper {some => 'data'}

Dump a Perl data structure with L<Data::Dumper>.

=head2 C<extends>

  % extends 'blue';
  % extends 'blue', title => 'Blue!';

Extend a template. All additional values get merged into the C<stash>.

=head2 C<flash>

  %= flash 'foo'

Alias for L<Mojolicious::Controller/"flash">.

=head2 C<include>

  %= include 'menubar'
  %= include 'menubar', format => 'txt'

Include a partial template, all arguments get localized automatically and are
only available in the partial template.

=head2 C<layout>

  % layout 'green';
  % layout 'green', title => 'Green!';

Render this template with a layout. All additional values get merged into the
C<stash>.

=head2 C<memorize>

  %= memorize begin
    %= time
  % end
  %= memorize {expires => time + 1} => begin
    %= time
  % end
  %= memorize foo => begin
    %= time
  % end
  %= memorize foo => {expires => time + 1} => begin
    %= time
  % end

Memorize block result in memory and prevent future execution.

=head2 C<param>

  %= param 'foo'

Alias for L<Mojolicious::Controller/"param">.

=head2 C<session>

  %= session 'foo'

Alias for L<Mojolicious::Controller/"session">.

=head2 C<stash>

  %= stash 'foo'
  % stash foo => 'bar';

Alias for L<Mojolicious::Controller/"stash">.

  %= stash 'name' // 'Somebody'

=head2 C<title>

  % title 'Welcome!';
  % title 'Welcome!', foo => 'bar';
  %= title

Page title. All additional values get merged into the C<stash>.

=head2 C<url_for>

  %= url_for 'named', controller => 'bar', action => 'baz'

Alias for L<Mojolicious::Controller/"url_for">.

=head2 C<url_with>

  %= url_with 'named', controller => 'bar', action => 'baz'

Does the same as C<url_for>, but inherits query parameters from the current
request.

  %= url_with->query([page => 2])

=head1 METHODS

L<Mojolicious::Plugin::DefaultHelpers> inherits all methods from
L<Mojolicious::Plugin> and implements the following new ones.

=head2 C<register>

  $plugin->register(Mojolicious->new);

Register helpers in L<Mojolicious> application.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojolicio.us>.

=cut
