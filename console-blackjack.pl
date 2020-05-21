#!/usr/bin/env perl

use v5.10;
use strict;
use warnings FATAL => 'all';

use diagnostics;
use Data::Dumper;
use Carp 'verbose';
$SIG{ __DIE__ } = sub { Carp::confess( @_ ) };

use utf8;
use open ':std', ':encoding(UTF-8)';

use constant {
  HARD => 0,
  SOFT => 1,
  WON  => 2,
  LOST => 3,
  PUSH => 4
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

sub dealer_upcard_is_ace {
  my ($dealer_hand) = @_;

  is_ace($dealer_hand->{cards}[0]);
}

sub clear {
  # system("export TERM=linux; clear");
}

sub draw_dealer_hand {
  my ($game) = @_;
  my $dealer_hand = $game->{dealer_hand};

  printf(" ");

  for (my $i = 0; $i < scalar(@{$dealer_hand->{cards}}); ++$i) {
    if ($i == 1 && $dealer_hand->{hide_down_card}) {
      printf("%s ", $game->{faces}[13][0]);
    } else {
      my $card = $dealer_hand->{cards}[$i];

      printf("%s ", $game->{faces}[$card->{value}][$card->{suit}]);
    }
  }

  printf(" ⇒  %u", dealer_hand_value($dealer_hand, SOFT));
}

sub draw_player_hand {
  my ($game, $index) = @_;
  my $player_hand = $game->{player_hands}[$index];

  printf(" ");

  for (my $i = 0; $i < scalar(@{$player_hand->{cards}}); ++$i) {
    my $card = $player_hand->{cards}[$i];
    printf("%s ", $game->{faces}[$card->{value}][$card->{suit}]);
  }

  printf(" ⇒  %u  ", player_hand_value($player_hand->{cards}, SOFT));

  if ($player_hand->{status} == LOST) {
    printf("-");
  } elsif ($player_hand->{status} == WON) {
    printf("+");
  }

  printf("\$%.2f", $player_hand->{bet} / 100.0);

  if (!$player_hand->{played} && $index == $game->{current_player_hand}) {
    printf(" ⇐");
  }

  printf("  ");

  if ($player_hand->{status} == LOST) {
    printf(player_is_busted($player_hand) ? "Busted!" : "Lose!");
  } elsif ($player_hand->{status} == WON) {
    printf(is_blackjack(&$player_hand->{hand}) ? "Blackjack!" : "Won!");
  } elsif ($player_hand->{status} == PUSH) {
    printf("Push");
  }

  printf("\n\n");
}

sub draw_hands {
  my ($game) = @_;

  clear();
  printf("\n Dealer: \n");
  draw_dealer_hand($game);
  printf("\n\n Player \$%.2f:\n", $game->{money} / 100.0);

  for (my $x = 0; $x < scalar(@{$game->{player_hands}}); $x++) {
    draw_player_hand($game, $x);
  }
}

sub read_one_char {
  open(TTY, "+</dev/tty") or die "no tty: $!";
  system "stty raw -echo min 1 time 1";
  my $c = utf8::decode(getc(TTY));
  system "stty sane";
  $c;
}

sub need_to_play_dealer_hand {
  my ($game) = @_;

  for (my $x = 0; $x < $game->{total_player_hands}; ++$x) {
    my $player_hand = $game->{player_hands}[$x];

    if (!(player_is_busted($player_hand) || is_blackjack($player_hand->{cards}))) {
      return 1;
    }
  }

  return 0;
}

sub play_dealer_hand {
  my ($game) = @_;

  my $dealer_hand = $game->{dealer_hand};

  if (is_blackjack($dealer_hand->{cards})) {
    $dealer_hand->{hide_down_card} = 0;
  }

  if (!need_to_play_dealer_hand($game)) {
    pay_hands($game);
    return;
  }

  $dealer_hand->{hide_down_card} = 0;

  my $soft_count = dealer_hand_value($dealer_hand, SOFT);
  my $hard_count = dealer_hand_value($dealer_hand, HARD);

  while ($soft_count < 18 && $hard_count < 17) {
    deal_card($game->{shoe}, $dealer_hand->{cards});
    $soft_count = dealer_hand_value($dealer_hand, SOFT);
    $hard_count = dealer_hand_value($dealer_hand, HARD);
  }

  pay_hands($game);
}

sub no_insurance {
  my ($game) = @_;

  if (is_blackjack($game->{dealer_hand}->{cards})) {
    $game->{dealer_hand}->{hide_down_card} = 0;

    pay_hands($game);
    draw_hands($game);
    bet_options($game);
    return;
  }

  my $player_hand = $game->{player_hands}[$game->{current_player_hand}];

  if (player_is_done($game, $player_hand)) {
    play_dealer_hand($game);
    draw_hands($game);
    bet_options($game);
    return;
  }

  draw_hands($game);
  player_get_action($game);
}

sub insure_hand {
  my ($game) = @_;

}

sub player_is_done {
  my ($game, $player_hand) = @_;


}

sub pay_hands {
  my ($game) = @_;

}

sub bet_options {
  my ($game) = @_;

}

sub player_get_action {
  my ($game) = @_;

}

sub save_game {
  my ($game) = @_;

}

sub ask_insurance {
  my ($game) = @_;

  printf(" Insurance?  (Y) Yes  (N) No\n");

  while (1) {
    my $c = read_one_char();

    if ($c eq "y") {
      insure_hand($game);
    } elsif ($c eq "n") {
      no_insurance($game);
    } else {
      clear();
      draw_hands($game);
      ask_insurance($game);
    }
  }
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

  draw_hands($game);

  if (dealer_upcard_is_ace(\%dealer_hand) && !is_blackjack(\$player_hand{cards})) {
    draw_hands($game);
    ask_insurance($game);
    return;
  }

  if (player_is_done($game, \%player_hand)) {
    $dealer_hand{hide_down_card} = 0;
    pay_hands($game);
    draw_hands($game);
    bet_options($game);
    return;
  }

  draw_hands($game);
  player_get_action($game);
  save_game($game);
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

deal_new_hand(\%game);
