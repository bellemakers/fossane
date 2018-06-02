# Copyright 2001-2003 Six Apart. This code cannot be redistributed without
# permission from www.movabletype.org.
#
# $Id: L10N.pm,v 1.3 2003/02/12 00:15:03 btrott Exp $

package MT::L10N;
use Locale::Maketext;

@MT::L10N::ISA = qw( Locale::Maketext );
@MT::L10N::Lexicon = (
    _AUTO => 1,
);

sub language_name {
    my $tag = $_[0]->language_tag;
    require I18N::LangTags::List;
    I18N::LangTags::List::name($tag);
}

sub encoding { 'iso-8859-1' }   ## Latin-1

1;
