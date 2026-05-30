// SPDX-License-Identifier: MIT
// Author: m26steph@uwaterloo.ca
// ThesisEngine — an on-chain investment thesis journal for traders.
// Think of it like a notebook where a trader writes down WHY they're making a trade,
// and the blockchain keeps that notebook tamper-proof and timestamped forever.
pragma solidity 0.8.34;

// Ownable2Step gives us a two-step ownership transfer — like a two-key safe,
// the new owner must explicitly accept ownership so you can't accidentally hand control to a wrong address.
// Ownable is the base that Ownable2Step extends.
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";

// ReentrancyGuard is a lock on the door — once a function is entered, no one can re-enter it
// until it finishes. This prevents the classic "reentrancy attack" where a malicious contract
// calls back into your function before it's done executing (like someone sneaking back into
// a revolving door before it completes its rotation).
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Pausable is an emergency stop button — the owner can freeze the contract if something goes wrong,
// like a circuit breaker in your house that trips when there's a power surge.
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

// Custom errors — these are cheaper than string-based revert messages (like sending a code instead of a letter).
// Each error is a unique identifier that tells the caller exactly what went wrong.

// Thrown when someone references a thesis ID that doesn't exist — like looking up a book by a call number that was never assigned.
error ThesisEngine__InvalidThesisId();

// Thrown when someone tries to modify a thesis that's already been closed — like trying to edit a sealed envelope.
error ThesisEngine__ThesisNotActive();

// Thrown when someone who is NOT the thesis creator tries to modify it — like someone else trying to edit YOUR diary entry.
error ThesisEngine__NotThesisOwner();

// Thrown when a thesis is created with zero tickers — like filing a trade idea without saying WHAT you want to trade.
error ThesisEngine__EmptyTicker();

// Thrown when the hold period is 0 or exceeds 56 days — like setting a timer for "never" or "too far out."
error ThesisEngine__InvalidTimeframe();

// Thrown when too many tickers are attached to one thesis — like trying to fit 50 items in a 20-slot backpack.
error ThesisEngine__MaxTickersExceeded();

// The main contract. It inherits three "superpowers":
// 1) Ownable2Step — safe ownership management (two-step transfer, like a relay baton handoff)
// 2) ReentrancyGuard — prevents recursive call exploits (the revolving door lock)
// 3) Pausable — emergency stop capability (the circuit breaker)
contract ThesisEngine is Ownable2Step, ReentrancyGuard, Pausable {

    // The maximum number of stock/crypto tickers allowed per thesis.
    // Think of it as the max number of ingredients you can list in a single recipe — capped at 20.
    uint256 public constant MAX_TICKERS_PER_THESIS = 20;

    // ThesisDirection describes the trader's bet:
    // LONG = "I think the price will go UP" (like buying low, hoping to sell high)
    // SHORT = "I think the price will go DOWN" (like borrowing a stock, selling it, and buying it back cheaper)
    // NEUTRAL = "I'm not betting on direction" (like a hedge or a market-neutral strategy)
    enum ThesisDirection { LONG, SHORT, NEUTRAL }

    // ThesisStatus tracks the lifecycle of a thesis:
    // ACTIVE = the thesis is live, the trade idea is still in play (the game is on)
    // CLOSED = the trader voluntarily closed it (the game ended normally)
    // INVALIDATED = the thesis was wrong or no longer relevant (the game was called off)
    enum ThesisStatus { ACTIVE, CLOSED, INVALIDATED }

    // DCFParams holds the inputs and outputs of a Discounted Cash Flow valuation.
    // DCF is a method to estimate what a company is REALLY worth by projecting future cash flows
    // and discounting them back to today's dollars — like asking "if this company will earn $X over
    // the next N years, what is that stream of money worth RIGHT NOW?"
    struct DCFParams {
        // The discount rate in basis points (1 bps = 0.01%).
        // This is the "opportunity cost" rate — the return you COULD get elsewhere.
        // Like saying "money today is worth more than money tomorrow, and here's by how much."
        uint256 discountRateBps;

        // The terminal growth rate in basis points — how fast the company grows FOREVER after the projection period.
        // Like assuming a tree will keep growing at a steady rate after you stop measuring it year by year.
        uint256 terminalGrowthBps;

        // How many years into the future we're projecting cash flows.
        // Like looking through a telescope — the further you look, the blurrier it gets.
        uint256 projectionYears;

        // The fair value per share in USD (scaled, e.g., 6 or 8 decimals) that the DCF model computed.
        // This is the "true price" the model says the stock SHOULD be worth — like an appraiser's estimate of a house.
        uint256 computedFairValueUSD;

        // The current market price in USD — what the stock is ACTUALLY trading at right now.
        // Like the listing price of a house on Zillow vs. what the appraiser says it's worth.
        uint256 currentPriceUSD;

        // The margin of safety in basis points — how much cheaper the current price is vs. fair value.
        // Like buying a house that's appraised at $500K for only $350K — the 30% discount is your safety cushion
        // in case the appraisal was too optimistic.
        uint256 marginOfSafetyBps;
    }

    // Thesis is the core data structure — one complete investment thesis record.
    // Think of it as a single page in a trader's journal, capturing everything about one trade idea.
    struct Thesis {
        // A unique numeric ID for this thesis — like a serial number on a receipt.
        uint256 id;

        // The Ethereum address of the trader who created this thesis — their digital signature/identity.
        address trader;

        // An array of ticker symbols (e.g., ["AAPL", "MSFT"]) — the assets this thesis is about.
        // Like listing which stocks you're watching for this particular trade idea.
        string[] tickers;

        // The direction of the trade — LONG, SHORT, or NEUTRAL (explained above).
        ThesisDirection direction;

        // The current status — ACTIVE, CLOSED, or INVALIDATED (explained above).
        ThesisStatus status;

        // The price at which the trader entered (or plans to enter) the position, in USD.
        // Like the price tag on the item when you bought it.
        uint256 entryPriceUSD;

        // The price the trader hopes the asset will reach — their profit target.
        // Like setting a goal: "I'll sell when it hits this price."
        uint256 targetPriceUSD;

        // The price at which the trader will cut losses — their safety net.
        // Like saying "if it drops to HERE, I'm out" to limit damage.
        uint256 stopLossUSD;

        // How many days the trader plans to hold the position.
        // Like a countdown timer on the trade — "I'll give this idea 30 days to play out  uint256 holdPeriodDays;

        // A self-assessed confidence score — how strongly the trader believes in this thesis.
        // Like rating your own confidence from 1-100 before an exam.
        uint256 convictionScore;

        // A keccak256 hash of the catalyst description — the EVENT the trader expects to move the price.
        // Stored as a hash (fingerprint) rather than raw text to save gas.
        // Like storing a fingerprint of a document instead of the whole document on-chain.
        bytes32 catalystHash;

        // The DCF valuation parameters associated with this thesis (explained above).
        DCFParams dcf;

        // The Unix timestamp when this thesis was created — block.timestamp at creation.
        // Like a "date written" stamp on a journal entry.
        uint256 createdAt;

        // The Unix timestamp when this thesis was closed — 0 if still active.
        // Like a "date completed" stamp.
        uint256 closedAt;

        // Free-text notes the trader writes when closing the thesis — a post-mortem.
        // Like writing "here's what I learned" at the end of an experiment.
        string closingNotes;
    }

    // A counter that auto-increments to assign unique IDs to each new thesis.
    // Like a ticket dispenser at a deli counter — each new customer gets the next number.
    uint256 private _nextThesisId;

    // A mapping from thesis ID to the full Thesis struct.
    // Like a filing cabinet where each drawer number (ID) contains one complete thesis folder.
    mapping(uint256 => Thesis) public theses;

    // A mapping from trader address to an array of thesis IDs they've created.
    // Like an index card for each trader listing all their thesis serial numbers.
    mapping(address => uint256[]) public traderTheses;

    // Emitted when a new thesis is created — a public announcement on the blockchain.
    // "indexed" parameters can be filtered/searched efficiently — like tags on a blog post.
    event ThesisCreated(
        uint256 indexed thesisId,       // Which thesis was created (searchable)
        address indexed trader,          // Who created it (searchable)
        ThesisDirection direction,       // LONG, SHORT, or NEUTRAL
        uint256 convictionScore          // How confident the trader is
    );

    // Emitted when a thesis is closed — like stamping "CASE CLOSED" on a file.
    event ThesisClosed(uint256 indexed thesisId, ThesisStatus status, string notes);

    // Emitted when the DCF parameters are updated — like revising an appraisal.
    event DCFUpdated(uint256 indexed thesisId, uint256 fairValue, uint256 marginOfSafety);

    // Emitted when the conviction score changes — like updating your confidence level mid-trade.
    event ConvictionUpdated(uint256 indexed thesisId, uint256 oldScore, uint256 newScore);

    // The constructor runs once when the contract is deployed.
    // It passes _owner to Ownable, setting the initial owner of the contract.
    // Like handing the keys to the building to the designated manager on opening day.
    constructor(address _owner) Ownable(_owner) {}

    // createThesis: the main function to record a new investment thesis on-chain.
    // nonReentrant = the revolving door lock (no re-entry while executing).
    // whenNotPaused = only works if the emergency stop hasn't been pulled.
    // Returns the newly assigned thesis ID.
    function createThesis(
        string[] calldata _tickers,        // The list of ticker symbols for this trade idea
        ThesisDirection _direction,         // LONG, SHORT, or NEUTRAL
        uint256 _entryPriceUSD,            // The entry price in USD
        uint256 _targetPriceUSD,           // The profit target price in USD
        uint256 _stopLossUSD,              // The stop-loss price in USD
        uint256 _holdPeriodDays,           // How many days to hold
        uint256 _convictionScore,          // Self-assessed confidence (e.g., 1-100)
        bytes32 _catalystHash,             // Hash of the catalyst event description
        DCFParams calldata _dcf            // The DCF valuation parameters
    ) external nonReentrant whenNotPaused returns (uint256 thesisId) {

        // If no tickers were provided, revert — you can't have a trade idea about nothing.
        // Like trying to place an order at a restaurant without choosing a dish.
        if (_tickers.length == 0) revert ThesisEngine__EmptyTicker();

        // If too many tickers were provided, revert — we cap at 20 to prevent gas abuse.
        // Like a bouncer enforcing a maximum occupancy rule.
        if (_tickers.length > MAX_TICKERS_PER_THESIS) revert ThesisEngine__MaxTickersExceeded();

        // If the hold period is 0 days (meaningless) or more than 56 days (beyond our allowed window), revert.
        // Like setting a kitchen timer — it must be between 1 and 56 days.
        if (_holdPeriodDays == 0 || _holdPeriodDays > 56) revert ThesisEngine__InvalidTimeframe();

        // Grab the next available ID and then increment the counter for the next caller.
        // Like tearing off a ticket number — you take the current one, and the next person getsext.
        thesisId = _nextThesisId++;

        // Get a storage pointer to the thesis slot in the mapping.
        // "storage" means we're writing directly to the blockchain's permanent memory,
        // like writing directly into the filing cabinet instead of on a sticky note first.
        Thesis storage t = theses[thesisId];

        // Store the thesis ID inside the struct itself (for convenience when reading it back).
        t.id = thesisId;

        // Record who created this thesis — msg.sender is the caller's Ethereum address.
        // Like signing your name at the top of a journal entry.
        t.trader = msg.sender;

        // Copy the ticker symbols array into storage.
        // Like writing down the list of stocks on the journal page.
        t.tickers = _tickers;

        // Record the trade direction — are we betting up, down, or sideways?
        t.direction = _direction;

        // Set the initial status to ACTIVE — this thesis is live and in play.
        t.status = ThesisStatus.ACTIVE;

        // Record the entry price — the price at which we're getting in.
        t.entryPriceUSD = _entryPriceUSD;

        // Record the target price — the price at which we'd take profit.
        t.targetPriceUSD = _targetPriceUSD;

        // Record the stop-loss price — the price at which we'd cut our losses.
        t.stopLossUSD = _stopLossUSD;

        // Record how long we plan to hold this position.
        t.holdPeriodDays = _holdPeriodDays;

        // Record our self-assessed conviction/confidence score.
        t.convictionScore = _convictionScore;

        // Record the hash of the catalyst — the event we think will move the price.
        t.catalystHash = _catalystHash;

        // Copy the entire DCF valuation struct into storage.
        // Like pasting a spreadsheet of financial calculations into the journal.
        t.dcf = _dcf;

        // Stamp the current block's timestamp as the creation time.
        // Like writing today's date on the journal entry.
        t.createdAt = block.timestamp;

        // Add this thesis ID to the trader's personal list of theses.
        // Like adding a bookmark to the trader's index of all their journal entries.
        traderTheses[msg.sender].push(thesisId);

        // Broadcast an event to the blockchain — anyone listening can see a new thesis was created.
        // Like posting a notification on a public bulletin board.
        emit ThesisCreated(thesisId, msg.sender, _direction, _convictionScore);
    }

    // closeThesis: marks a thesis as CLOSED or INVALIDATED and records closing notes.
    // nonReentrant = the revolving door lock again.
    // Only the original trader can close their own thesis — like only you can close your own diary entry.
    function closeThesis(uint256 _thesisId, ThesisStatus _status, string calldata _notes) external nonReentrant {

        // Fetch the thesis from storage by its ID.
        // Like pulling a specific folder out of the filing cabinet.
        Thesis storage t = theses[_thesisId];

        // Check that the caller is the trader who created this thesis.
        // If not, revert — you can't close someone else's trade journal entry.
        if (t.trader != msg.sender) revert ThesisEngine__NotThesisOwner();

        // Check that the thesis is still ACTIVE — you can't close something that's already closed.
        // Like trying to seal an envelope that's already been sealed.
        if (t.status != ThesisStatus.ACTIVE) revert ThesisEngine__ThesisNotActive();

        // Update the status to whatever the trader chose (CLOSED or INVALIDATED).
        t.status = _status;

        // Stamp the closing time — record when this thesis was wrapped up.
        t.closedAt = block.timestamp;

        // Store the trader's closing notes — their post-mortem analysis.
        // Like writing "lessons learned" at the bottom of the journal page.
        t.closingNotes = _notes;

        // Broadcast that this thesis has been closed.
        emit ThesisClosed(_thesisId, _status, _notes);
    }

    // updateDCF: allows the trader to revise their DCF valuation while the thesis is still active.
    // Like updating your financial model spreadsheet when new earnings data comes out.
    function updateDCF(uint256 _thesisId, DCFParams calldata _dcf) external {

        // Fetch the thesis from storage.
        Thesis storage t = theses[_thesisId];

        // Only the thesis creator can update it — your spreadsheet, your edits.
        if (t.trader != msg.sender) revert ThesisEngine__NotThesisOwner();

        // Can only update if the thesis is still active — no editing sealed records.
        if (t.status != ThesisStatus.ACTIVE) revert ThesisEngine__ThesisNotActive();

        // Overwrite the old DCF parameters with the new ones.
        t.dcf = _dcf;

        // Broadcast that the DCF was updated, including the new fair value and margin of safety.
        emit DCFUpdated(_thesisId, _dcf.computedFairValueUSD, _dcf.marginOfSafetyBps);
    }

    // updateConviction: allows the trader to change their confidence score while the thesis is active.
    // Like re-rating your confidence on an exam question after reading it more carefully.
    function updateConviction(uint256 _thesisId, uint256 _newScore) external {

        // Fetch the thesis from storage.
        Thesis storage t = theses[_thesisId];

        // Only the thesis creator can update their own conviction — your confidence, your call.
        if (t.trader != msg.sender) revert ThesisEngine__NotThesisOwner();

        // Can only update if the thesis is still active.
        if (t.status != ThesisStatus.ACTIVE) revert ThesisEngine__ThesisNotActive();

        // Save the old score so we can include it in the event (for before/after comparison).
        uint256 oldScore = t.convictionScore;

        // Overwrite with the new conviction score.
        t.convictionScore = _newScore;

        // Broadcast the change — "conviction went from X to Y."
        emit ConvictionUpdated(_thesisId, oldScore, _newScore);
    }

    // getTraderThesisCount: returns how many theses a given trader has created.
    // "view" means it only reads data, costs no gas when called off-chain.
    // Like asking "how many journal entries does this person have?"
    function getTraderThesisCount(address _trader) external view returns (uint256) {
        // Return the length of the trader's thesis ID array — the count of their entries.
        return traderTheses[_trader].length;
    }

    // getTraderThesisIds: returns the full list of thesis IDs for a given trader.
    // Like getting the table of contents from a trader's journal.
    function getTraderThesisIds(address _trader) external view returns (uint256[] memory) {
        // Return the entire array of thesis IDs belonging to this trader.
        return traderTheses[_trader];
    }

    // getThesisTickers: returns the ticker symbols for a specific thesis.
    // Like asking "which stocks was this trade idea about?"
    function getThesisTickers(uint256 _thesisId) external view returns (string[] memory) {
        // Return the tickers array from the thesis struct.
        return theses[_thesisId].tickers;
    }

    // getThesisDCF: returns the DCF valuation parameters for a specific thesis.
    // Like pulling up the financial model attached to a particular trade idea.
    function getThesisDCF(uint256 _thesisId) external view returns (DCFParams memory) {
        // Return the DCF sub-struct from the thesis.
        return theses[_thesisId].dcf;
    }

    // pause: the owner can hit the emergency stop button, freezing all thesis creation.
    // Only callable by the contract owner — like only the building manager can pull the fire alarm.
    function pause() external onlyOwner {
        // Activate the pause state via OpenZeppelin's internal _pause() function.
        _pause();
    }

    // unpause: the owner can release the emergency stop, resuming normal operations.
    // Like the building manager resetting the fire alarm after the drill is over.
    function unpause() external onlyOwner {
        // Deactivate the pause state via OpenZeppelin's internal _unpause() function.
        _unpause();
    }
}
