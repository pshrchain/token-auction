pragma solidity ^0.4.17;

import './base.t.sol';

contract SetUpTest is AuctionTest {
    function testSetUp() public {
        assertEq(t2.balanceOf(bidder1), 1000 * T2);
        assertEq(t2.allowance(bidder1, manager), 1000 * T2);
    }
}

contract NewAuctionTest is AuctionTest {
    function newAuction() public returns (uint, uint) {
        return manager.newAuction( seller    // beneficiary
                                 , t1        // selling
                                 , t2        // buying
                                 , 100 * T1  // sell_amount
                                 , 10 * T2   // start_bid
                                 , 1         // min_increase (%)
                                 , 1 years   // ttl
                                 );
    }
    function testNewAuctionEvent() public {
        var (id, base) = newAuction();

        expectEventsExact(manager);
        LogNewAuction(id, base);
    }
    function testNewAuction() public {
        var (id,) = newAuction();
        assertEq(id, 1);

        var (beneficiary, selling, buying,
             sell_amount, start_bid, min_increase, ttl) = manager.getAuction(id);

        assertEq(beneficiary, seller);
        assert(selling == ERC20(t1));
        assert(buying == ERC20(t2));
        assertEq(sell_amount, 100 * T1);
        assertEq(start_bid, 10 * T2);
        assertEq(min_increase, 1);
        assertEq(ttl, 1 years);
    }
    function testNewAuctionTransfersToManager() public {
        var balance_before = t1.balanceOf(manager);
        newAuction();
        var balance_after = t1.balanceOf(manager);

        assertEq(balance_after - balance_before, 100 * T1);
    }
    function testNewAuctionTransfersFromCreator() public {
        var balance_before = t1.balanceOf(this);
        newAuction();
        var balance_after = t1.balanceOf(this);

        assertEq(balance_before - balance_after, 100 * T1);
    }
    function testNewAuctionlet() public {
        var (id, base) = newAuction();

        // can't always know what the auctionlet id is as it is
        // only an internal type. But for the case of a single auction
        // there should be a single auctionlet created with id 1.
        var (auction_id, last_bidder,
             buy_amount, sell_amount) = manager.getAuctionlet(base);

        assertEq(auction_id, id);
        assertEq(last_bidder, seller);
        assertEq(buy_amount, 10 * T2);
        assertEq(sell_amount, 100 * T1);
    }
}

contract BidTest is AuctionTest {
    function newAuction() public returns (uint, uint) {
        return manager.newAuction( seller    // beneficiary
                                 , t1        // selling
                                 , t2        // buying
                                 , 100 * T1  // sell_amount
                                 , 10 * T2   // start_bid
                                 , 1         // min_increase (%)
                                 , 1 years   // ttl
                                 );
    }
    function testBidEvent() public {
        var (id, base) = newAuction();
        bidder1.doBid(base, 11 * T2, false);
        bidder2.doBid(base, 12 * T2, false);

        expectEventsExact(manager);
        LogNewAuction(id, base);
        LogBid(base);
        LogBid(base);
    }
    function testFailBidUnderMinBid() public {
        var (, base) = newAuction();
        bidder1.doBid(base, 9 * T2, false);
    }
    function testBid() public {
        var (, base) = newAuction();
        bidder1.doBid(base, 11 * T2, false);

        var (, last_bidder1,
             buy_amount,) = manager.getAuctionlet(base);

        assertEq(last_bidder1, bidder1);
        assertEq(buy_amount, 11 * T2);
    }
    function testFailBidTransfer() public {
        var (, base) = newAuction();

        // this should throw as bidder1 only has 1000 t2
        bidder1.doBid(base, 1001 * T2, false);
    }
    function testBidTransfer() public {
        var (, base) = newAuction();

        var bidder1_t2_balance_before = t2.balanceOf(bidder1);
        bidder1.doBid(base, 11 * T2, false);
        var bidder1_t2_balance_after = t2.balanceOf(bidder1);

        var balance_diff = bidder1_t2_balance_before - bidder1_t2_balance_after;
        assertEq(balance_diff, 11 * T2);
    }
    function testBidReturnsToPrevBidder() public {
        var (, base) = newAuction();

        var bidder1_t2_balance_before = t2.balanceOf(bidder1);
        bidder1.doBid(base, 11 * T2, false);
        bidder2.doBid(base, 12 * T2, false);
        var bidder1_t2_balance_after = t2.balanceOf(bidder1);

        var bidder_balance_diff = bidder1_t2_balance_before - bidder1_t2_balance_after;
        assertEq(bidder_balance_diff, 0 * T2);
    }
    function testFailBidExpired() public {
        var (, base) = newAuction();
        bidder1.doBid(base, 11 * T2, false);

        // force expiry
        manager.addTime(2 years);

        bidder2.doBid(base, 12 * T2, false);
    }
    function testBaseDoesNotExpire() public {
        var (, base) = newAuction();

        // push past the base auction ttl
        manager.addTime(2 years);

        // this should succeed as there are no real bidders
        bidder1.doBid(base, 11 * T2, false);
    }
    function testBidTransfersBenefactor() public {
        var (, base) = newAuction();

        var balance_before = t2.balanceOf(seller);
        bidder1.doBid(base, 40 * T2, false);
        var balance_after = t2.balanceOf(seller);

        assertEq(balance_after - balance_before, 40 * T2);
    }
    function testBidTransfersToDistinctBeneficiary() public {
        var (, base) = manager.newAuction(bidder2, t1, t2, 100 * T1, 0 * T2, 1, 1 years);

        var balance_before = t2.balanceOf(bidder2);
        bidder1.doBid(base, 10 * T2, false);
        var balance_after = t2.balanceOf(bidder2);

        assertEq(balance_after - balance_before, 10 * T2);
    }
}

contract MultipleAuctionTest is AuctionTest {
    function newAuction() public returns (uint, uint) {
        return manager.newAuction( seller    // beneficiary
                                 , t1        // selling
                                 , t2        // buying
                                 , 100 * T1  // sell_amount
                                 , 10 * T2   // start_bid
                                 , 1         // min_increase (%)
                                 , 1 years   // ttl
                                 );
    }
    function testMultipleNewAuctions() public {
        // auction manager should be able to manage multiple auctions
        t2.transfer(seller, 200 * T2);
        seller.doApprove(manager, 200 * T2, t2);

        var t1_balance_before = t1.balanceOf(this);
        var t2_balance_before = t2.balanceOf(this);

        var (id1,) = newAuction();
        // flip tokens around
        var (id2,) = manager.newAuction(seller, t2, t1, 100 * T2, 10 * T1, 1, 1 years);

        assertEq(id1, 1);
        assertEq(id2, 2);

        assertEq(t1_balance_before - t1.balanceOf(this), 100 * T1);
        assertEq(t2_balance_before - t2.balanceOf(this), 100 * T2);

        var (beneficiary, selling, buying,
             sell_amount, start_bid, min_increase, ttl) = manager.getAuction(id2);

        assertEq(beneficiary, seller);
        assert(selling == ERC20(t2));
        assert(buying == ERC20(t1));
        assertEq(sell_amount, 100 * T2);
        assertEq(start_bid, 10 * T1);
        assertEq(min_increase, 1);
        assertEq(ttl, 1 years);
    }
    function testMultipleAuctionsBidTransferToBenefactor() public {
        var (, base1) = newAuction();
        var (, base2) = newAuction();

        var seller_t2_balance_before = t2.balanceOf(seller);

        bidder1.doBid(base1, 11 * T2, false);
        bidder2.doBid(base2, 11 * T2, false);

        var seller_t2_balance_after = t2.balanceOf(seller);

        var diff_t2 = seller_t2_balance_after - seller_t2_balance_before;

        assertEq(diff_t2, 22 * T2);
    }
    function testMultipleAuctionsTransferFromCreator() public {
        var balance_before = t1.balanceOf(this);

        newAuction();
        newAuction();

        var balance_after = t1.balanceOf(this);

        assertEq(balance_before - balance_after, 200 * T1);
    }
}

contract MinBidIncreaseTest is AuctionTest {
    function newAuction() public returns (uint, uint) {
        return manager.newAuction( seller    // beneficiary
                                 , t1        // selling
                                 , t2        // buying
                                 , 100 * T1  // sell_amount
                                 , 10 * T2   // start_bid
                                 , 20        // min_increase (%)
                                 , 1 years   // ttl
                                 );
    }
    function testFailFirstBidEqualStartBid() public {
        var (, base) = newAuction();
        bidder1.doBid(base, 10 * T2, false);
    }
    function testFailSubsequentBidEqualLastBid() public {
        var (, base) = newAuction();
        bidder1.doBid(base, 13 * T2, false);
        bidder2.doBid(base, 13 * T2, false);
    }
    function testFailFirstBidLowerThanMinIncrease() public {
        var (, base) = newAuction();
        bidder1.doBid(base, 11 * T2, false);
    }
    function testFailSubsequentBidLowerThanMinIncrease() public {
        var (, base) = newAuction();
        bidder1.doBid(base, 12 * T2, false);
        bidder2.doBid(base, 13 * T2, false);
    }
}

contract AssertionTest is DSTest, Assertive() {
    function testAssert() public pure {
        assert(2 > 1);
    }
    function testFailAssert() public pure {
        assert(2 < 1);
    }
    function testIncreasingNoop() public pure {
        uint[] memory array = new uint[](1);
        array[0] = 1;
        assertIncreasing(array);
    }
    function testIncreasing() public pure {
        uint[] memory array = new uint[](2);
        array[0] = 1;
        array[1] = 2;
        assertIncreasing(array);
    }
    function testFailIncreasing() public pure {
        uint[] memory array = new uint[](2);
        array[0] = 2;
        array[1] = 1;
        assertIncreasing(array);
    }
}

contract ClaimTest is AuctionTest {
    function newAuction() public returns (uint, uint) {
        return manager.newAuction( beneficiary1  // beneficiary
                                 , t1            // selling
                                 , t2            // buying
                                 , 100 * T1      // sell_amount
                                 , 10 * T2       // start_bid
                                 , 1             // min_increase (%)
                                 , 1 years       // ttl
                                 );
    }
    function testClaimTransfersBidder() public {
        var (, base) = newAuction();
        bidder1.doBid(base, 11 * T2, false);
        // force expiry
        manager.addTime(2 years);

        var balance_before = t1.balanceOf(bidder1);
        // n.b. anyone can force claim, not just the bidder
        bidder1.doClaim(base);
        var balance_after = t1.balanceOf(bidder1);

        assertEq(balance_after - balance_before, 100 * T1);
    }
    function testClaimNonParty() public {
        var (, base) = newAuction();
        bidder1.doBid(base, 11 * T2, false);
        manager.addTime(2 years);

        var balance_before = t1.balanceOf(bidder1);
        // n.b. anyone can force claim, not just the bidder
        bidder2.doClaim(base);
        var balance_after = t1.balanceOf(bidder1);

        assertEq(balance_after - balance_before, 100 * T1);
    }
    function testFailClaimProceedingsPreExpiration() public {
        // bidders cannot claim their auctionlet until the auction has
        // expired.
        var (, base) = newAuction();
        bidder1.doBid(base, 11 * T2, false);
        bidder1.doClaim(base);
    }
    function testFailBidderClaimAgain() public {
        // bidders should not be able to claim their auctionlet more than once
        var (, base1) = newAuction();
        var (, base2) = newAuction();

        // create bids on two different auctions so that the manager has
        // enough funds for us to attempt to withdraw all at once
        bidder1.doBid(base1, 11 * T2, false);
        bidder2.doBid(base2, 11 * T2, false);

        // force expiry
        manager.addTime(2 years);

        // now attempt to claim the proceedings from the first
        // auctionlet twice
        bidder1.doClaim(base1);
        bidder1.doClaim(base1);
    }
    function testFailClaimBase() public {
        // base auctionlets should not be claimable
        var (, base) = newAuction();
        manager.addTime(2 years);

        // The beneficiary is set as the last bidder on the base auctionlet,
        // so that they get transferred the start bid. They should not be able
        // to claim the base auctionlet.
        beneficiary1.doClaim(base);
    }
    function testFailClaimBaseNonParty() public {
        // base auctionlets should not be claimable
        var (, base) = newAuction();
        manager.addTime(2 years);

        manager.claim(base);  // doesn't matter who calls claim
    }
}

// New auctions have an optional ttl parameter that sets a global
// auction expiry (across all of its auctionlets). After this expiry, no
// more bids can be placed and bid winners can claim their bids. In
// contrast to the per-auctionlet expiry (which does not apply to unbid
// collateral), following the auction expiry the collateral can be
// claimed (and sent to the beneficiary) even if there have been no bids.
contract ExpiryTest is AuctionTest {
    function newAuction(uint64 ttl, uint64 expiration)
        public
        returns (uint, uint)
    {
        return manager.newAuction( beneficiary1  // beneficiary
                                 , t1            // selling
                                 , t2            // buying
                                 , 100 * T1      // sell_amount
                                 , 0             // start_bid
                                 , 0             // min_increase (%)
                                 , ttl
                                 , expiration
                                 );
    }
    function testExpiryTimes() public {
        var (, base) = newAuction({ ttl:        uint64(20 days)
                                    , expiration: uint64(now + 10 days) });

        assert(!manager.isExpired(base));
        manager.addTime(8 days);
        assert(!manager.isExpired(base));
        manager.addTime(8 days);
        assert(manager.isExpired(base));
        manager.addTime(8 days);
        assert(manager.isExpired(base));
    }
    function testFailBidPostAuctionExpiryPreAuctionletExpiry() public {
        var (, base) = newAuction({ ttl:        uint64(20 days)
                                    , expiration: uint64(now + 10 days) });

        manager.addTime(15 days);

        // fails because auction has expired
        bidder1.doBid(base, 1 * T2, false);
    }
    function testFailBidPostAuctionletExpiryPostAuctionExpiry() public {
        var (, base) = newAuction({ ttl:        uint64(20 days)
                                    , expiration: uint64(now + 10 days) });

        bidder1.doBid(base, 1 * T2, false);
        manager.addTime(25 days);

        bidder2.doBid(base, 2 * T2, false);
    }
    function testFailSplitPostAuctionExpiryPreAuctionletExpiry() public {
        var (, base) = newAuction({ ttl:        uint64(20 days)
                                    , expiration: uint64(now + 10 days) });

        manager.addTime(15 days);

        bidder1.doBid(base, 1 * T2, 50 * T1, false);
    }
    function testFailSplitPostAuctionletExpiryPostAuctionExpiry() public {
        var (, base) = newAuction({ ttl:        uint64(20 days)
                                    , expiration: uint64(now + 10 days) });

        bidder1.doBid(base, 1 * T2, false);
        manager.addTime(25 days);

        bidder2.doBid(base, 1 * T2, 50 * T1, false);
    }
    function testClaimBasePostAuctionExpiryPreAuctionletExpiry() public {
        var (, base) = newAuction({ ttl:        uint64(20 days)
                                    , expiration: uint64(now + 10 days) });

        manager.addTime(15 days);

        var balance_before = t1.balanceOf(beneficiary1);
        manager.claim(base);
        assertEq(t1.balanceOf(beneficiary1) - balance_before, 100 * T1);
    }
    function testClaimBasePostAuctionExpiryPostAuctionletExpiry() public {
        var (, base) = newAuction({ ttl:        uint64(20 days)
                                    , expiration: uint64(now + 10 days) });

        manager.addTime(25 days);

        var balance_before = t1.balanceOf(beneficiary1);
        manager.claim(base);
        assertEq(t1.balanceOf(beneficiary1) - balance_before, 100 * T1);
    }
    function testClaimPostAuctionExpiryPostAuctionletExpiry() public {
        var (, base) = newAuction({ ttl:        uint64(20 days)
                                    , expiration: uint64(now + 10 days) });

        bidder1.doBid(base, 1 * T2, false);
        manager.addTime(15 days);

        var balance_before = t1.balanceOf(bidder1);
        manager.claim(base);
        assertEq(t1.balanceOf(bidder1) - balance_before, 100 * T1);
    }
    function testClaimPostAuctionExpiryPreAuctionletExpiry() public {
        var (, base) = newAuction({ ttl:        uint64(20 days)
                                    , expiration: uint64(now + 10 days) });

        bidder1.doBid(base, 1 * T2, false);
        manager.addTime(25 days);

        var balance_before = t1.balanceOf(bidder1);
        manager.claim(base);
        assertEq(t1.balanceOf(bidder1) - balance_before, 100 * T1);
    }
}
