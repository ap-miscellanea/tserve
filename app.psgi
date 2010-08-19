#!/usr/bin/perl
use strict;
use Plack::Builder;
use Plack::Util ();
use Template ();
use Encode ();

{
package Plack::App::Directory::WithIndex;
use parent qw(Plack::App::Directory);
use File::Spec ();
sub serve_path {
	my $self = shift;
	my ( $env, $path ) = @_;
	if ( -d $path ) {
		if ( $env->{'PATH_INFO'} !~ m!(?:\A|/)\z! ) {
			my $uri = $env->{'PATH_INFO'} . '/';
			my $qs  = $env->{'QUERY_STRING' };
			$uri .= '?' . $qs if length $qs;
			return [ 301, [ Location => $uri ] ];
		}
		my $try = File::Spec->catfile( $path, 'index.html' );
		return $self->SUPER::serve_path( $env, $try ) if -e $try;
	}
	return $self->SUPER::serve_path( @_ );
}
}

my $file = Plack::App::Directory::WithIndex->new( root => 'www' )->to_app;

my $ttmw = sub {
	my $app = shift;
	my $tt = Template->new( { INCLUDE_PATH => 'inc', ENCODING => 'UTF-8' } );
	sub {
		my $env = shift;
		my $res = $app->( $env );
		my $type = Plack::Util::header_get( $res->[1], 'Content-Type' );
		if ( $type =~ m!\Atext/html *(?:;|\z)! ) {
			my ( $tmpl, $out );
			Plack::Util::foreach( $res->[2], sub { $tmpl .= shift } );
			$tt->process( \$tmpl, {}, \$out ) or do {
				Plack::Util::header_set( $res->[1], 'Content-Type', 'text/plain' );
				$out = $tt->error;
			};
			$res->[2] = [ $out = Encode::encode( 'UTF-8', $out ) ];
			Plack::Util::header_set( $res->[1], 'Content-Length', length $out );
		}
		return $res;
	};
};

builder {
	enable $ttmw;
	$file;
}
