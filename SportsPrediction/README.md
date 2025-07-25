# Decentralized Sports Prediction Market

A transparent, automated sports betting platform built on Stacks blockchain with fair odds, pool-based betting, and instant payouts.

## Overview

This smart contract enables decentralized sports betting where odds are determined by actual betting volume, outcomes are resolved by trusted oracles, and winnings are automatically distributed to winners.

## Key Features

- **Fair Odds System**: Real-time odds based on betting pool distribution
- **Automated Payouts**: Smart contract handles all winnings automatically
- **Multiple Outcomes**: Support for Team A, Team B, or Draw results
- **Oracle Resolution**: Trusted oracle system for accurate event outcomes
- **Pool-Based Betting**: Parimutuel system where winners share total pool
- **Platform Security**: Time-locked betting and anti-manipulation measures

## Contract Functions

### Event Management
- `create-event(title, team-a, team-b, event-date, duration)` - Create new betting event
- `resolve-event(event-id, outcome)` - Oracle resolves event outcome
- `cancel-event(event-id)` - Cancel event if needed

### Betting System
- `place-bet(event-id, outcome, amount)` - Place bet on event outcome
- `claim-winnings(event-id, bet-id)` - Claim winnings after event resolution
- `get-current-odds(event-id, outcome)` - Check live odds

### Information
- `get-event(event-id)` - View event details and pools
- `get-user-bet(event-id, user, bet-id)` - Check specific bet details
- `get-platform-stats()` - Platform statistics and settings

## How It Works

1. **Event Creation**: Admin creates sports events with teams and betting deadline
2. **Place Bets**: Users bet STX on Team A, Team B, or Draw outcomes
3. **Dynamic Odds**: Odds update automatically based on betting volume
4. **Event Resolution**: Oracle resolves outcome after event concludes
5. **Claim Winnings**: Winners claim their share of the total betting pool

## Economic Model

- **Minimum Bet**: 1 STX
- **Maximum Bet**: 100,000 STX
- **Platform Fee**: 2.5% on all bets
- **Payout Formula**: `(Your Bet / Winning Pool) × Total Pool`
- **Fair Distribution**: Winners share pool proportionally to bet size

## Betting Outcomes

| Outcome | Code | Description |
|---------|------|-------------|
| Team A | 1 | First team wins |
| Team B | 2 | Second team wins |
| Draw | 3 | Tie/Draw result |

## Use Cases

- **Professional Sports**: NFL, NBA, MLB, soccer matches
- **Esports**: Gaming tournaments and competitions
- **Political Events**: Election outcomes and predictions
- **Entertainment**: Award shows, reality TV results
- **Financial Markets**: Cryptocurrency price movements

## Benefits

- **Transparent Odds**: All calculations visible on-chain
- **No House Edge**: Peer-to-peer betting with minimal platform fee
- **Global Access**: Anyone can participate regardless of location
- **Instant Settlement**: Automatic payouts upon resolution
- **Fair System**: Odds determined by actual market demand

## Security

- Betting closes before event starts
- Oracle-based outcome resolution
- Time-locked event resolution
- Admin emergency controls
- Automatic payout system

Built for Stacks blockchain using Clarity smart contracts.