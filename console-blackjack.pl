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

sub dealer_hand_value {
  my ($dealer_hand, $method) = @_;

  my $total = 0;

  for my $i (0 .. scalar(@{$dealer_hand->{cards}}) - 1) {

    if ($i == 1 && $dealer_hand->{hide_down_card}) {
      next;
    }

    my $tmp_v = @{$dealer_hand->{cards}}[$i]->{value} + 1;
    my $v = $tmp_v > 9 ? 10 : $tmp_v;

    if ($method eq SOFT && $v == 1 && $total < 11) {
      $v = 11;
    }

    $total += $v;
  }

  if ($method eq SOFT && $total > 21) {
    return dealer_hand_value($dealer_hand, HARD);
  }

  $total;
}

sub player_hand_value {
  my ($cards, $method) = @_;
  my $total = 0;

  for (@{$cards}) {
    my $tmp_v = $_->{value} + 1;
    my $v = $tmp_v > 9 ? 10 : $tmp_v;

    if ($method eq SOFT && $v == 1 && $total < 11) {
      $v = 11;
    }

    $total += $v;
  }

  if ($method eq SOFT && $total > 21) {
    return player_hand_value($cards, HARD);
  }

  $total;
}

sub player_is_busted {
  my ($player_hand) = @_;

  player_hand_value($player_hand, SOFT) > 21 ? 1 : 0;
}

sub is_blackjack {
  my ($cards) = @_;

  if (scalar @$cards != 2) {
    return 0;
  }

  if (is_ace(@$cards[0]) && is_ten(@$cards[1])) {
    return 1;
  }

  is_ace(@$cards[1]) && is_ten(@$cards[0]) ? 1 : 0;
}

sub player_can_hit {
  my ($player_hand) = @_;

  ($player_hand->{played}
    || $player_hand->{stood}
    || 21 == player_hand_value($player_hand, HARD)
    || is_blackjack($player_hand->{cards})
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

sub need_to_shuffle {
  my ($game) = @_;

  1; # TODO
}

sub deal_card {
  my ($shoe, $cards) = @_;

  my $card = pop(@{$shoe});
  push @{$cards}, $card;
}

sub deal_new_hand {
  my ($game) = @_;

  if (need_to_shuffle($game)) {
    new_regular($game);
  }

  my %player_hand = (cards => [], bet => $game->{current_bet}, stood => 0, played => 0, payed => 0, status => 0);
  my %dealer_hand = (cards => [], hide_down_card => 1);

  deal_card($game->{shoe}, (\%player_hand)->{cards});
  deal_card($game->{shoe}, (\%dealer_hand)->{cards});
  deal_card($game->{shoe}, (\%player_hand)->{cards});
  deal_card($game->{shoe}, (\%dealer_hand)->{cards});

  $game->{player_hands}[0] = \%player_hand;
  $game->{current_player_hand} = 0;

  $game->{dealer_hand} = \%dealer_hand;

  # if (dealer_upcard_is_ace(dealer_hand) && !is_blackjack(&player_hand.hand)) {
  #   draw_hands(game);
  #   ask_insurance(game);
  #   return;
  # }
  #
  # if (player_is_done(game, &player_hand)) {
  #   dealer_hand->hide_down_card = false;
  #   pay_hands(game);
  #   draw_hands(game);
  #   bet_options(game);
  #   return;
  # }
  #
  # draw_hands(game);
  # player_get_action(game);
  # save_game(game);
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
