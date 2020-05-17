#!/usr/bin/env perl

use v5.10;
use strict;
use warnings FATAL => 'all';
use Data::Dumper;

use constant {
  HARD => 'hard',
  SOFT => 'soft'
};

my @faces = (
  ["🂡", "🂱", "🃁", "🃑"],
  ["🂢", "🂲", "🃂", "🃒"],
  ["🂣", "🂳", "🃃", "🃓"],
  ["🂤", "🂴", "🃄", "🃔"],
  ["🂥", "🂵", "🃅", "🃕"],
  ["🂦", "🂶", "🃆", "🃖"],
  ["🂧", "🂷", "🃇", "🃗"],
  ["🂨", "🂸", "🃈", "🃘"],
  ["🂩", "🂹", "🃉", "🃙"],
  ["🂪", "🂺", "🃊", "🃚"],
  ["🂫", "🂻", "🃋", "🃛"],
  ["🂭", "🂽", "🃍", "🃝"],
  ["🂮", "🂾", "🃎", "🃞"],
  ["🂠"]
);

sub is_ace {
  my ($card) = @_;
  !$card->{'value'};
}

sub is_ten {
  my ($card) = @_;
  $card->{'value'} > 8;
}

sub player_get_value {
  my ($player_hand, $method) = @_;

  my $v = 0;
  my $total = 0;
  my $tmp_v = 0;

  for (@{$player_hand->{'hand'}}) {
    $tmp_v = $_->{'value'} + 1;
    $v = $tmp_v > 9 ? 10 : $tmp_v;

    if ($method eq SOFT && $v == 1 && $total < 11) {
      $v = 11;
    }

    $total += $v;
  }

  if ($method eq SOFT && $total > 21) {
    return player_get_value($player_hand, HARD);
  }

  $total;
}

sub player_is_busted {
  my ($player_hand) = @_;

  player_get_value($player_hand, SOFT) > 21 ? 1 : 0;
}

sub is_blackjack {
  my ($hand) = @_;

  if (scalar @$hand != 2) {
    return 0;
  }

  if (is_ace(@$hand[0]) && is_ten(@$hand[1])) {
    return 1;
  }

  is_ace(@$hand[1]) && is_ten(@$hand[0]) ? 1 : 0;
}

sub player_can_hit {
  my ($player_hand) = @_;

  ($player_hand->{'played'}
    || $player_hand->{'stood'}
    || 21 == player_get_value($player_hand, HARD)
    || is_blackjack($player_hand->{'hand'})
    || player_is_busted($player_hand)) ? 0 : 1;
}

my %card_1 = (suit => 2, value => 2);
my %card_2 = (suit => 2, value => 4);

my @hand = (\%card_1, \%card_2);

my %player_hand = (hand => [@hand], played => 0, stood => 0);

say player_can_hit(\%player_hand);
