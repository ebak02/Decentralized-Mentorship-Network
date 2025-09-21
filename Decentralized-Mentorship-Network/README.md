# Decentralized Mentorship Network

A blockchain-based mentorship platform built on Stacks that connects mentors and mentees with tokenized incentives and transparent reputation systems.

##  Overview

The Decentralized Mentorship Network is a smart contract that facilitates peer-to-peer mentorship with built-in payment processing, reputation management, and tokenized incentives. Mentors can monetize their expertise while mentees gain access to quality guidance in a trustless environment.

##  Features

- **Mentor Registration**: Experts can register with their expertise areas and hourly rates
- **Mentee Onboarding**: Simple registration process for knowledge seekers
- **Session Booking**: Automated payment processing and session scheduling
- **Reputation System**: Bidirectional rating system for quality assurance
- **Earnings Management**: Secure withdrawal system for mentors
- **Platform Governance**: Administrative controls for fee management
- **Stake-Based Trust**: Mentors stake STX to participate, ensuring commitment

##  Contract Functions

### Public Functions

#### Mentor Functions
- `register-mentor(expertise, hourly-rate)` - Register as a mentor with expertise and rate
- `update-mentor-profile(expertise, hourly-rate)` - Update mentor information
- `complete-session(session-id)` - Mark session as completed
- `rate-mentee(session-id, rating)` - Rate mentee performance (1-5 stars)
- `withdraw-earnings(amount)` - Withdraw earned STX tokens
- `deactivate-mentor()` - Temporarily disable mentor account

#### Mentee Functions
- `register-mentee()` - Register as a mentee
- `book-session(mentor, duration-hours)` - Book and pay for mentorship session
- `rate-mentor(session-id, rating)` - Rate mentor performance (1-5 stars)

#### Administrative Functions
- `update-platform-fee(new-fee)` - Update platform commission (owner only)
- `update-min-stake(new-amount)` - Update minimum mentor stake (owner only)
- `withdraw-platform-fees(amount)` - Withdraw platform earnings (owner only)

### Read-Only Functions
- `get-mentor(mentor)` - Retrieve mentor profile and statistics
- `get-mentee(mentee)` - Retrieve mentee profile and statistics
- `get-session(session-id)` - Get detailed session information
- `get-mentor-earnings(mentor)` - Check mentor's earnings and balance
- `get-platform-stats()` - View platform-wide statistics

##  Architecture

### Data Structures

#### Mentors Map
```clarity
{
  expertise: string-utf8,
  hourly-rate: uint,
  rating: uint,
  total-sessions: uint,
  is-active: bool,
  stake-amount: uint
}
```

#### Sessions Map
```clarity
{
  mentor: principal,
  mentee: principal,
  duration-hours: uint,
  hourly-rate: uint,
  total-amount: uint,
  status: string-ascii,
  created-at: uint,
  completed-at: optional uint,
  mentor-rating: optional uint,
  mentee-rating: optional uint
}
```

### Economic Model

1. **Mentor Staking**: Mentors must stake a minimum amount (default: 1 STX) to participate
2. **Session Payments**: Mentees pay upfront for booked sessions
3. **Platform Fees**: 5% commission on all transactions (adjustable by admin)
4. **Earnings Distribution**: Mentors receive 95% of session fees upon completion

##  Installation & Deployment

### Prerequisites
- Clarinet CLI installed
- Stacks wallet for deployment
- Basic understanding of Clarity smart contracts

### Local Development
```bash
# Clone the repository
git clone <repository-url>
cd mentorship-network

# Initialize Clarinet project
clarinet new mentorship-network
cd mentorship-network

# Add the contract
cp mentorship-network.clar contracts/

# Run tests
clarinet test

# Check contract
clarinet check
```

### Deployment
```bash
# Deploy to testnet
clarinet deploy --testnet

# Deploy to mainnet
clarinet deploy --mainnet
```

##  Usage Examples

### Becoming a Mentor
```clarity
;; Register as a blockchain expert charging 0.1 STX per hour
(contract-call? .mentorship-network register-mentor 
  u"Blockchain Development & Smart Contracts" 
  u100000) ;; 0.1 STX in microSTX
```

### Booking a Session
```clarity
;; Book 2-hour session with a specific mentor
(contract-call? .mentorship-network book-session 
  'ST1MENTOR123... 
  u2)
```

### Rating and Feedback
```clarity
;; Rate mentor after session completion
(contract-call? .mentorship-network rate-mentor 
  u1 ;; session-id
  u5) ;; 5-star rating
```

##  Security Features

- **Access Controls**: Function-level permissions prevent unauthorized actions
- **Stake Requirements**: Mentors must stake tokens, reducing spam and ensuring commitment
- **Escrow System**: Payments are held in contract until session completion
- **Rating Validation**: Ratings are limited to 1-5 range with proper authorization checks
- **Overflow Protection**: Safe arithmetic operations prevent integer overflow

##  Platform Economics

- **Default Platform Fee**: 5% (50 basis points)
- **Minimum Mentor Stake**: 1 STX
- **Maximum Platform Fee**: 20% (admin adjustable)
- **Payment Currency**: STX tokens

##  Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

##  License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

##  Disclaimer

This smart contract is provided as-is for educational and development purposes. Always audit smart contracts thoroughly before deploying to mainnet with real funds.

##  Support

For questions and support:
- Create an issue in the repository
- Join our Discord community
- Follow us on Twitter for updates

## 🗺 Roadmap

- [ ] Multi-token payment support
- [ ] Dispute resolution system
- [ ] Advanced matching algorithms
- [ ] Mobile app integration
- [ ] Certification and achievement NFTs
- [ ] Subscription-based mentorship models
