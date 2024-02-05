import "./Token.sol";

contract Hub {
    uint256 public immutable inflation; // the inflation rate expressed as 1 + percentage inflation, aka 7% inflation is 107
    uint256 public immutable divisor; // the largest power of 10 the inflation rate can be divided by
    uint256 public immutable period; // the amount of sections between inflation steps
    string public symbol;
    string public name;
    uint256 public immutable signupBonus; // a one-time payout made immediately on signup
    uint256 public immutable initialIssuance; // the starting payout per second, this gets inflated by the inflation rate
    uint256 public immutable deployedAt; // the timestamp this contract was deployed at
    uint256 public immutable timeout; // longest a token can go without a ubi payout before it gets deactivated

    mapping (address => Token) public userToToken;
    mapping (address => address) public tokenToUser;
    mapping (address => bool) public organizations;
    mapping (address => mapping (address => uint256)) public limits;

    event Signup(address indexed user, address token);
    event OrganizationSignup(address indexed organization);
    event Trust(address indexed canSendTo, address indexed user, uint256 limit);
    event HubTransfer(address indexed from, address indexed to, uint256 amount);

    // some data types used for validating transitive transfers
    struct transferValidator {
        bool seen;
        uint256 sent;
        uint256 received;
    }
    mapping (address => transferValidator) public validation;
    address[] public seen;


    /// @notice trust a user, calling this means you're able to receive tokens from this user transitively
    /// @dev the trust graph is weighted and directed
    /// @param user the user to be trusted
    /// @param limit the amount this user is trusted, as a percentage of 100
    function trust(address user, uint limit) public {
        // only users who have signed up as tokens or organizations can enter the trust graph
        require(address(userToToken[msg.sender]) != address(0) || organizations[msg.sender], "You can only trust people after you've signed up!");
        // you must continue to trust yourself 100%
        require(msg.sender != user, "You can't untrust yourself");
        // organizations can't receive trust since they don't have their own token (ie. there's nothing to trust)
        require(organizations[user] == false, "You can't trust an organization");
        // must a percentage
        require(limit <= 100, "Limit must be a percentage out of 100");
        // organizations don't have a token to base send limits off of, so they can only trust at rates 0 or 100
        if (organizations[msg.sender]) {
            require(limit == 0 || limit == 100, "Trust is binary for organizations");
        }
        _trust(user, limit);
    }

    /// @dev used internally in both the trust function and signup
    /// @param user the user to be trusted
    /// @param limit the amount this user is trusted, as a percentage of 100
    function _trust(address user, uint limit) internal {
        limits[msg.sender][user] = limit;
        emit Trust(msg.sender, user, limit);
    }

    /// @notice finds the maximum amount of a specific token that can be sent between two users
    /// @dev the goal of this function is to always return a sensible number, it's used to validate transfer throughs, and also heavily in the graph/pathfinding services
    /// @param tokenOwner the safe/owner that the token was minted to
    /// @param src the sender of the tokens
    /// @param dest the recipient of the tokens
    /// @return the amount of tokenowner's token src can send to dest
    function checkSendLimit(address tokenOwner, address src, address dest) public view returns (uint256) {

        // there is no trust
        if (limits[dest][tokenOwner] == 0) {
            return 0;
        }

        // if dest hasn't signed up, they cannot trust anyone
        if (address(userToToken[dest]) == address(0) && !organizations[dest] ) {
            return 0;
        }

        //if the token doesn't exist, it can't be sent/accepted
        if (address(userToToken[tokenOwner]) == address(0)) {
             return 0;
        }

        uint256 srcBalance = userToToken[tokenOwner].balanceOf(src);

        // if sending dest's token to dest, src can send 100% of their holdings
        // for organizations, trust is binary - if trust is not 0, src can send 100% of their holdings
        if (tokenOwner == dest || organizations[dest]) {
            return srcBalance;
        }

        // find the amount dest already has of the token that's being sent
        uint256 destBalance = userToToken[tokenOwner].balanceOf(dest);

        uint256 oneHundred = 100;
        
        // find the maximum possible amount based on dest's trust limit for this token
        uint256 max = (userToToken[dest].balanceOf(dest) * (limits[dest][tokenOwner])) / (oneHundred);
        
        // if trustLimit has already been overriden by a direct transfer, nothing more can be sent
        if (max < destBalance) return 0;

        uint256 destBalanceScaled = destBalance * (oneHundred - (limits[dest][tokenOwner])) / oneHundred;
        
        // return the max amount dest is willing to hold minus the amount they already have
        return max - (destBalanceScaled);
    }

    /// @dev builds the validation data structures, called for each transaction step of a transtive transactions
    /// @param src the sender of a single transaction step
    /// @param dest the recipient of a single transaction step
    /// @param wad the amount being passed along a single transaction step
    function buildValidationData(address src, address dest, uint wad) internal {
        // the validation mapping has this format
        // { address: {
        //     seen: whether this user is part of the transaction,
        //     sent: total amount sent by this user,
        //     received: total amount received by this user,
        //    }
        // }
        if (validation[src].seen != false) {
            // if we have seen the addresses, increment their sent amounts
            validation[src].sent = validation[src].sent + (wad);
        } else {
            // if we haven't, add them to the validation mapping
            validation[src].seen = true;
            validation[src].sent = wad;
            seen.push(src);
        }
        if (validation[dest].seen != false) {
            // if we have seen the addresses, increment their sent amounts
            validation[dest].received = validation[dest].received + (wad);
        } else {
            // if we haven't, add them to the validation mapping
            validation[dest].seen = true;
            validation[dest].received = wad; 
            seen.push(dest);   
        }
    }

    /// @dev performs the validation for an attempted transitive transfer
    /// @param steps the number of steps in the transitive transaction
    function validateTransferThrough(uint256 steps) internal {
        // a valid path has only one real sender and receiver
        address src;
        address dest;
        // iterate through the array of all the addresses that were part of the transaction data
        for (uint i = 0; i < seen.length; i++) {
            transferValidator memory curr = validation[seen[i]];
            // if the address sent more than they received, they are the sender
            if (curr.sent > curr.received) {
                // if we've already found a sender, transaction is invalid
                require(src == address(0), "Path sends from more than one src");
                // the real token sender must also be the transaction sender
                require(seen[i] == msg.sender, "Path doesn't send from transaction sender");
                src = seen[i];
            }
            // if the address received more than they sent, they are the recipient
            if (curr.received > curr.sent) {
                // if we've already found a recipient, transaction is invalid
                require(dest == address(0), "Path sends to more than one dest");
                dest = seen[i];
            }
        }
        // a valid path has both a sender and a recipient
        require(src != address(0), "Transaction must have a src");
        require(dest != address(0), "Transaction must have a dest");
        // sender should not recieve, recipient should not send
        // by this point in the code, we should have one src and one dest and no one else's balance should change
        require(validation[src].received == 0, "Sender is receiving");
        require(validation[dest].sent == 0, "Recipient is sending");
        // the total amounts sent and received by sender and recipient should match
        require(validation[src].sent == validation[dest].received, "Unequal sent and received amounts");
        // the maximum amount of addresses we should see is one more than steps in the path
        require(seen.length <= steps + 1, "Seen too many addresses");
        emit HubTransfer(src, dest, validation[src].sent);
        // clean up the validation datastructures
        for (uint i = seen.length; i >= 1; i--) {
            delete validation[seen[i-1]];
        }
        delete seen;
        // sanity check that we cleaned everything up correctly
        require(seen.length == 0, "Seen should be empty");
    }

    /// @notice walks through tokenOwners, srcs, dests, and amounts array and executes transtive transfer
    /// @dev tokenOwners[0], srcs[0], dests[0], and wads[0] constitute a transaction step
    /// @param tokenOwners the owner of the tokens being sent in each transaction step
    /// @param srcs the sender of each transaction step
    /// @param dests the recipient of each transaction step
    /// @param wads the amount for each transaction step
    function transferThrough(
        address[] memory tokenOwners,
        address[] memory srcs,
        address[] memory dests,
        uint[] memory wads
    ) public {
        // all the arrays must be the same length
        require(dests.length == tokenOwners.length, "Tokens array length must equal dests array");
        require(srcs.length == tokenOwners.length, "Tokens array length must equal srcs array");
        require(wads.length == tokenOwners.length, "Tokens array length must equal amounts array");
        for (uint i = 0; i < srcs.length; i++) {
            address src = srcs[i];
            address dest = dests[i];
            address token = tokenOwners[i];
            uint256 wad = wads[i];
            
            // check that no trust limits are violated
            uint256 max = checkSendLimit(token, src, dest);
            require(wad <= max, "Trust limit exceeded");

            buildValidationData(src, dest, wad);
            
            // go ahead and do the transfers now so that we don't have to walk through this array again
            userToToken[token].hubTransfer(src, dest, wad);
        }
        // this will revert if there are any problems found
        validateTransferThrough(srcs.length);
    }
}

