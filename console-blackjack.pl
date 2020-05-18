#!/usr/bin/env perl

use v5.10;
use strict;
use warnings FATAL => 'all';
use Data::Dumper;

use constant {
  HARD => 'hard',
  SOFT => 'soft'
};

my @shuffle_specs = (
  [95, 8],
  [92, 7],
  [89, 6],
  [86, 5],
  [84, 4],
  [82, 3],
  [81, 2],
  [80, 1]
);

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
  !$card->{value};
}

sub is_ten {
  my ($card) = @_;
  $card->{value} > 8;
}

sub player_get_value {
  my ($player_hand, $method) = @_;

  my $v = 0;
  my $total = 0;
  my $tmp_v = 0;

  for (@{$player_hand->{hand}}) {
    $tmp_v = $_->{value} + 1;
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

  ($player_hand->{played}
    || $player_hand->{stood}
    || 21 == player_get_value($player_hand, HARD)
    || is_blackjack($player_hand->{hand})
    || player_is_busted($player_hand)) ? 0 : 1;
}

sub player_can_stand {
  my ($player_hand) = @_;

  ($player_hand->{stood}
    || player_is_busted($player_hand)
    || is_blackjack($player_hand->{hand})) ? 0 : 1;
}

sub all_bets {
  my ($game) = @_;
  my $bets = 0;

  for (@{$game->{player_hands}}) {
    $bets += $_->{bet};
  }

  return $bets;
}

sub shuffle {
  my ($shoe) = @_;

  for (my $i = @{${$shoe}}; --$i;) {
    my $j = int rand($i + 1);
    @{${$shoe}}[$i, $j] = @{${$shoe}}[$j, $i];
  }
}

sub new_regular {
  my ($game) = @_;

  for (my $deck = 0; $deck < $game->{num_decks}; ++$deck) {
    for (my $suit = 0; $suit < 4; ++$suit) {
      for (my $value = 0; $value < 13; ++$value) {
        my %c = (suit => $suit, value => $value);
        push @{$game->{shoe}}, \%c;
      }
    }
  }

  shuffle(\$game->{shoe});
}

sub deal_new_hand {
  my ($game) = @_;

  print Dumper($game);
}

my %game = (
  shoe => [],
  dealer_hand => {},
  player_hands => [],
  num_decks => 1,
  money => 10000,
  current_bet => 500,
  current_player_hand => 0,
  shuffle_specs => [@shuffle_specs],
  faces => [@faces]
);

new_regular(\%game);
deal_new_hand(\%game);
