#!/usr/bin/env perl

use v5.10;
use strict;
use warnings FATAL => 'all';

use diagnostics;
use Data::Dumper;
use Carp 'verbose';
$SIG{ __DIE__ } = sub {Carp::confess(@_)};

use utf8;
use open ':std', ':encoding(UTF-8)';

use constant {
  SAVE_FILE        => 'bj.txt',
  CARDS_IN_DECK    => 52,
  MAX_DECKS        => 8,
  MAX_PLAYER_HANDS => 7,
  MIN_BET          => 500,
  MAX_BET          => 10000000,
  HARD             => 0,
  SOFT             => 1,
  WON              => 2,
  LOST             => 3,
  PUSH             => 4
};

my @shuffle_specs = (
  [ 95, 8 ],
  [ 92, 7 ],
  [ 89, 6 ],
  [ 86, 5 ],
  [ 84, 4 ],
  [ 82, 3 ],
  [ 81, 2 ],
  [ 80, 1 ]
);

my @faces = (
  [ "🂡", "🂱", "🃁", "🃑" ],
  [ "🂢", "🂲", "🃂", "🃒" ],
  [ "🂣", "🂳", "🃃", "🃓" ],
  [ "🂤", "🂴", "🃄", "🃔" ],
  [ "🂥", "🂵", "🃅", "🃕" ],
  [ "🂦", "🂶", "🃆", "🃖" ],
  [ "🂧", "🂷", "🃇", "🃗" ],
  [ "🂨", "🂸", "🃈", "🃘" ],
  [ "🂩", "🂹", "🃉", "🃙" ],
  [ "🂪", "🂺", "🃊", "🃚" ],
  [ "🂫", "🂻", "🃋", "🃛" ],
  [ "🂭", "🂽", "🃍", "🃝" ],
  [ "🂮", "🂾", "🃎", "🃞" ],
  [ "🂠" ]
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

  player_hand_value($player_hand->{cards}, SOFT) > 21 ? 1 : 0;
}

sub is_blackjack {
  my ($cards) = @_;

  if (scalar(@{$cards}) != 2) {
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
    || 21 == player_hand_value($player_hand->{cards}, HARD)
    || is_blackjack($player_hand->{cards})
    || player_is_busted($player_hand)) ? 0 : 1;
}

sub player_can_stand {
  my ($player_hand) = @_;

  ($player_hand->{stood}
    || player_is_busted($player_hand)
    || is_blackjack($player_hand->{cards})) ? 0 : 1;
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

sub new_aces {
  my ($game) = @_;

  my $total_cards = $game->{num_decks} * CARDS_IN_DECK;

  while (scalar(@{$game->{shoe}}) < $total_cards) {
    for (my $suit = 0; $suit < 4; ++$suit) {
      last if scalar(@{$game->{shoe}}) >= $total_cards;
      my %c = (suit => $suit, value => 0);
      push @{$game->{shoe}}, \%c;
    }
  }

  shuffle(\$game->{shoe});
}

sub new_jacks {
  my ($game) = @_;

  my $total_cards = $game->{num_decks} * CARDS_IN_DECK;

  while (scalar(@{$game->{shoe}}) < $total_cards) {
    for (my $suit = 0; $suit < 4; ++$suit) {
      last if scalar(@{$game->{shoe}}) >= $total_cards;
      my %c = (suit => $suit, value => 10);
      push @{$game->{shoe}}, \%c;
    }
  }

  shuffle(\$game->{shoe});
}

sub new_aces_jacks {
  my ($game) = @_;

  my $total_cards = $game->{num_decks} * CARDS_IN_DECK;

  while (scalar(@{$game->{shoe}}) < $total_cards) {
    for (my $suit = 0; $suit < 4; ++$suit) {
      last if scalar(@{$game->{shoe}}) >= $total_cards;
      my %c1 = (suit => $suit, value => 0);
      push @{$game->{shoe}}, \%c1;

      last if scalar(@{$game->{shoe}}) >= $total_cards;
      my %c2 = (suit => $suit, value => 10);
      push @{$game->{shoe}}, \%c2;
    }
  }

  shuffle(\$game->{shoe});
}

sub new_sevens {
  my ($game) = @_;

  my $total_cards = $game->{num_decks} * CARDS_IN_DECK;

  while (scalar(@{$game->{shoe}}) < $total_cards) {
    for (my $suit = 0; $suit < 4; ++$suit) {
      last if scalar(@{$game->{shoe}}) >= $total_cards;
      my %c = (suit => $suit, value => 6);
      push @{$game->{shoe}}, \%c;
    }
  }

  shuffle(\$game->{shoe});
}

sub new_eights {
  my ($game) = @_;

  my $total_cards = $game->{num_decks} * CARDS_IN_DECK;

  while (scalar(@{$game->{shoe}}) < $total_cards) {
    for (my $suit = 0; $suit < 4; ++$suit) {
      last if scalar(@{$game->{shoe}}) >= $total_cards;
      my %c = (suit => $suit, value => 7);
      push @{$game->{shoe}}, \%c;
    }
  }

  shuffle(\$game->{shoe});
}

sub need_to_shuffle {
  my ($game) = @_;

  my $used = (scalar(@{$game->{shoe}}) / $game->{num_decks} * 52) * 100.0;

  for (my $x = 0; $x < MAX_DECKS; ++$x) {
    if ($game->{num_decks} == $game->{shuffle_specs}[$x][1] && $used > $game->{shuffle_specs}[$x][0]) {
      return 1;
    }
  }

  return 0;
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
  system("export TERM=linux; clear");
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
    printf(is_blackjack($player_hand->{cards}) ? "Blackjack!" : "Won!");
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
  my $c = getc(TTY);
  system "stty sane";
  $c;
}

sub need_to_play_dealer_hand {
  my ($game) = @_;

  for (my $x = 0; $x < scalar(@{$game->{player_hands}}); ++$x) {
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

  my $player_hand = $game->{player_hands}[$game->{current_player_hand}];

  $player_hand->{bet} /= 2;
  $player_hand->{played} = 1;
  $player_hand->{payed} = 1;
  $player_hand->{status} = LOST;
  $game->{money} -= $player_hand->{bet};

  draw_hands($game);
  bet_options($game);
}

sub player_is_done {
  my ($game, $player_hand) = @_;

  if ($player_hand->{played}
    || $player_hand->{stood}
    || is_blackjack($player_hand->{cards})
    || player_is_busted($player_hand)
    || 21 == player_hand_value($player_hand->{cards}, SOFT)
    || 21 == player_hand_value($player_hand->{cards}, HARD)) {

    $player_hand->{played} = 1;

    if (!$player_hand->{payed} && player_is_busted($player_hand)) {
      $player_hand->{payed} = 1;
      $player_hand->{status} = LOST;
      $game->{money} -= $player_hand->{bet};
    }

    return 1;
  }

  0;
}

sub normalize_bet {
  my ($game) = @_;

  if ($game->{current_bet} < MIN_BET) {
    $game->{current_bet} = MIN_BET;
  } elsif ($game->{current_bet} > MAX_BET) {
    $game->{current_bet} = MAX_BET;
  }

  if ($game->{current_bet} > $game->{money}) {
    $game->{current_bet} = $game->{money};
  }
}

sub dealer_is_busted {
  my ($dealer_hand) = @_;

  dealer_hand_value($dealer_hand, SOFT) > 21 ? 1 : 0;
}

sub pay_hands {
  my ($game) = @_;

  my $dealer_hand = $game->{dealer_hand};
  my $dhv = dealer_hand_value($dealer_hand, SOFT);
  my $dhb = dealer_is_busted($dealer_hand);

  for (my $x = 0; $x < scalar(@{$game->{player_hands}}); ++$x) {
    my $player_hand = $game->{player_hands}[$x];

    if ($player_hand->{payed}) {
      next;
    }

    $player_hand->{payed} = 1;

    my $phv = player_hand_value($player_hand->{cards}, SOFT);

    if ($dhb || $phv > $dhv) {
      if (is_blackjack($player_hand->{cards})) {
        $player_hand->{bet} = $player_hand->{bet} * 1.5;
      }

      $game->{money} += $player_hand->{bet};
      $player_hand->{status} = WON;
    } elsif ($phv < $dhv) {
      $game->{money} -= $player_hand->{bet};
      $player_hand->{status} = LOST;
    } else {
      $player_hand->{status} = PUSH;
    }
  }

  normalize_bet($game);
  save_game($game);
}

sub get_new_bet {
  my ($game) = @_;

  clear();
  draw_hands($game);

  printf("  Current Bet: \$%u  Enter New Bet: \$", ($game->{current_bet} / 100));

  my $tmp = <STDIN>;
  chomp $tmp;

  $game->{current_bet} = $tmp * 100;
  normalize_bet($game);
  deal_new_hand($game);
}

sub get_new_num_decks {
  my ($game) = @_;

  clear();
  draw_hands($game);

  printf("  Number Of Decks: %u  Enter New Number Of Decks (1-8): ", ($game->{num_decks}));

  my $tmp = <STDIN>;

  if ($tmp < 1) {$tmp = 1;}
  if ($tmp > 8) {$tmp = 8;}

  $game->{num_decks} = $tmp;
  game_options($game);
}

sub get_new_deck_type {
  my ($game) = @_;

  clear();
  draw_hands($game);
  printf(" (1) Regular  (2) Aces  (3) Jacks  (4) Aces & Jacks  (5) Sevens  (6) Eights\n");

  my $c = read_one_char();

  if ($c eq '1') {
    new_regular($game);
  } elsif ($c eq '2') {
    new_aces($game);
  } elsif ($c eq '3') {
    new_jacks($game);
  } elsif ($c eq '4') {
    new_aces_jacks($game);
  } elsif ($c eq '5') {
    new_sevens($game);
  } elsif ($c eq '6') {
    new_eights($game);
  } else {
    clear();
    draw_hands($game);
    game_options($game);
  }

  draw_hands($game);
  bet_options($game);
}

sub game_options {
  my ($game) = @_;

  clear();
  draw_hands($game);
  printf(" (N) Number of Decks  (T) Deck Type  (B) Back\n");

  my $c = read_one_char();

  if ($c eq 'n') {
    get_new_num_decks($game);
  } elsif ($c eq 't') {
    get_new_deck_type($game);
  } elsif ($c eq 'b') {
    clear();
    draw_hands($game);
    bet_options($game);
  } else {
    clear();
    draw_hands($game);
    game_options($game);
  }
}

sub bet_options {
  my ($game) = @_;

  printf(" (D) Deal Hand  (B) Change Bet  (O) Options  (Q) Quit\n");

  my $c = read_one_char();

  if ($c eq 'd') {
    deal_new_hand($game);
  } elsif ($c eq 'b') {
    get_new_bet($game);
  } elsif ($c eq 'o') {
    game_options($game);
  } elsif ($c eq "q") {
    clear();
  } else {
    print "here 2!";
    clear();
    draw_hands($game);
    bet_options($game);
  }
}

sub player_can_split {
  my ($game) = @_;

  my $player_hand = $game->{player_hands}[$game->{current_player_hand}];

  if ($player_hand->{stood} || scalar(@{$game->{player_hands}}) >= MAX_PLAYER_HANDS) {
    return 0;
  }

  if ($game->{money} < all_bets($game) + $player_hand->{bet}) {
    return 0;
  }

  return scalar(@{$player_hand->{cards}}) == 2 && $player_hand->{cards}[0]->{value} == $player_hand->{cards}[0]->{value} ? 1 : 0;
}

sub player_can_dbl {
  my ($game) = @_;

  my $player_hand = $game->{player_hands}[$game->{current_player_hand}];

  if ($game->{money} < all_bets($game) + $player_hand->{bet}) {
    return 0;
  }

  if ($player_hand->{stood}
    || scalar(@{$player_hand->{cards}}) != 2
    || player_is_busted($player_hand)
    || is_blackjack($player_hand->{cards})) {
    return 0;
  }

  1;
}

sub process {
  my ($game) = @_;

  if (more_hands_to_play($game)) {
    play_more_hands($game);
    return;
  }

  play_dealer_hand($game);
  draw_hands($game);
  bet_options($game);
}

sub more_hands_to_play {
  my ($game) = @_;

  $game->{current_player_hand} < scalar(@{$game->{player_hands}}) - 1;
}

sub play_more_hands {
  my ($game) = @_;

  my $player_hand = $game->{player_hands}[++($game->{current_player_hand})];
  deal_card($game->{shoe}, $player_hand->{cards});

  if (player_is_done($game, $player_hand)) {
    process($game);
    return;
  }

  draw_hands($game);
  player_get_action($game);
}

sub player_hit {
  my ($game) = @_;

  my $player_hand = $game->{player_hands}[$game->{current_player_hand}];
  deal_card($game->{shoe}, $player_hand->{cards});

  if (player_is_done($game, $player_hand)) {
    process($game);
    return;
  }

  draw_hands($game);
  player_get_action($game);
}

sub player_stand {
  my ($game) = @_;

  my $player_hand = $game->{player_hands}[$game->{current_player_hand}];

  $player_hand->{stood} = 1;
  $player_hand->{played} = 1;

  if (more_hands_to_play($game)) {
    play_more_hands($game);
    return;
  }

  play_dealer_hand($game);
  draw_hands($game);
  bet_options($game);
}

sub player_split {
  my ($game) = @_;

  my %new_hand = (cards => [], bet => $game->{current_bet}, stood => 0, played => 0, payed => 0, status => 0);
  my $hand_count = scalar(@{$game->{player_hands}});

  if (!player_can_split($game)) {
    draw_hands($game);
    player_get_action($game);
    return;
  }

  $game->{player_hands}[scalar(@{$game->{player_hands}}) + 1] = \%new_hand;

  while ($hand_count > $game->{current_player_hand}) {
    $game->{player_hands}[$hand_count] = $game->{player_hands}[$hand_count - 1];
    --$hand_count;
  }

  my $this_hand = $game->{player_hands}[scalar(@{$game->{player_hands}})];
  my $split_hand = $game->{player_hands}[scalar(@{$game->{player_hands}}) + 1];

  my $card = $this_hand->{cards}[1];
  $split_hand->{cards}[0] = $card;
  deal_card($game->{shoe}, $this_hand->{cards});

  if (player_is_done($game, $this_hand)) {
    process($game);
    return;
  }

  draw_hands($game);
  player_get_action($game);
}

sub player_dbl {
  my ($game) = @_;

  my $player_hand = $game->{player_hands}[$game->{current_player_hand}];

  deal_card($game->{shoe}, $player_hand->{cards});
  $player_hand->{played} = 1;
  $player_hand->{bet} *= 2;

  if (player_is_done($game, $player_hand)) {
    process($game);
  }
}

sub player_get_action {
  my ($game) = @_;

  my $player_hand = $game->{player_hands}[$game->{current_player_hand}];
  printf(" ");

  if (player_can_hit($player_hand)) {printf("(H) Hit  ");}
  if (player_can_stand($player_hand)) {printf("(S) Stand  ");}
  if (player_can_split($game)) {printf("(P) Split  ");}
  if (player_can_dbl($game)) {printf("(D) Double  ");}

  printf("\n");

  my $c = read_one_char();

  if ($c eq 'h') {
    player_hit($game);
  } elsif ($c eq 's') {
    player_stand($game);
  } elsif ($c eq 'p') {
    player_split($game);
  } elsif ($c eq 'd') {
    player_dbl($game);
  } else {
    clear();
    draw_hands($game);
    player_get_action($game);

  }
}

sub save_game {
  my ($game) = @_;

  open(my $fh, '>:encoding(UTF-8)', SAVE_FILE) or die $!;
  printf($fh "%u\n%u\n%u\n", $game->{num_decks}, $game->{money}, $game->{current_bet});
  close($fh);
}

sub ask_insurance {
  my ($game) = @_;

  printf(" Insurance?  (Y) Yes  (N) No\n");

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

  if (dealer_upcard_is_ace(\%dealer_hand) && !is_blackjack((\%player_hand)->{cards})) {
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

sub load_game {
  my ($game) = @_;

  if (open(my $fh, '<:encoding(UTF-8)', SAVE_FILE)) {
    my $line = <$fh>;
    chomp $line;
    $game->{num_decks} = int($line);

    $line = <$fh>;
    chomp $line;
    $game->{money} = int($line);

    $line = <$fh>;
    chomp $line;
    $game->{current_bet} = int($line);

    close($fh);
  }
}

my %game = (
  shoe                => [],
  dealer_hand         => {},
  player_hands        => [],
  num_decks           => 1,
  money               => 10000,
  current_bet         => 500,
  current_player_hand => 0,
  shuffle_specs       => [ @shuffle_specs ],
  faces               => [ @faces ]
);

load_game(\%game);
new_regular(\%game);
deal_new_hand(\%game);
