select * from epochs order by epoch desc limit 1;

-- 1）总锁仓金额
select sum(amount) from (
                            select totalvalidatorbalance / 1e9 as amount  from epochs where epoch = (select max(epoch) from epochs)
                            union
                            select sum(ed.amount) / 1e9 from eth1_deposits as ed
                                                                 left join validators as v on  encode(ed.publickey, 'hex') = v.pubkeyhex
                            where
                                (v.pubkeyhex is null and ed.valid_signature is true)  -- 在validator中不存在
                               or (v.pubkeyhex is not null and v.activationepoch > (select max(epoch) from epochs)) --在validator中存在但还未激活
                            union
                            select sum(balance) / 1e9 from validators
                            where pubkeyhex is not null and exitepoch <= (select max(epoch) from epochs) and (select max(epoch) from epochs) < withdrawableepoch --已退出，但是还没到账的
                            union
                            select sum(balance) / 1e9 from validators
                            where pubkeyhex is not null and exitepoch <= (select max(epoch) from epochs) and (select max(epoch) from epochs) >= withdrawableepoch --已完成退出，但未配置提款地址
                              and substring(encode(withdrawalcredentials,  'hex'),1,2) = '00'
                        ) as t

-- 2) 活跃的Validators
select count(*) from validators
where activationepoch <= (select max(epoch) from epochs) and (select max(epoch) from epochs) < exitepoch

-- 3) deposited和pending的Validators
select count(distinct ed.publickey) from eth1_deposits as ed
                                             left join validators as v on  encode(ed.publickey, 'hex') = v.pubkeyhex
where
    (v.pubkeyhex is null and ed.valid_signature is true)  -- 在validator中不存在
   or
    (v.pubkeyhex is not null and v.activationepoch > (select max(epoch) from epochs)) --在validator中存在但还未激活



-- 4）已经申请退出等待Withdraw提款的所有validator的数量和金额（自愿和强制的都有，并且款未到账）
select count(*), sum(balance) from validators
where exitepoch != 9223372036854775807
and (
	(select max(epoch) from epochs) < exitepoch  --已申请，还未到 exitepoch
	or 
	((select max(epoch) from epochs) >= exitepoch and (select max(epoch) from epochs) <  withdrawableepoch ) --到达exitepoch，但还没拿到钱
	or 
	((select max(epoch) from epochs) > withdrawableepoch and substring(encode(withdrawalcredentials,  'hex'),1,2) = '00' )) -- 应该可以拿到钱了，但是没配置提现地址

-- 4.1）自愿退出等待Withdraw提款（款未到账）
select v.validatorindex, substring(encode(withdrawalcredentials,  'hex'),1,2), v.exitepoch, v.withdrawableepoch  from blocks_voluntaryexits as bv
                                                                                                                          join validators as v on bv.validatorindex = v.validatorindex
where exitepoch != 9223372036854775807
and (
	(select max(epoch) from epochs) < exitepoch  --已申请，还未到 exitepoch
	or 
	((select max(epoch) from epochs) >= exitepoch and (select max(epoch) from epochs) <  withdrawableepoch ) --到达exitepoch，但还没拿到钱
	or 
	((select max(epoch) from epochs) > withdrawableepoch and substring(encode(withdrawalcredentials,  'hex'),1,2) = '00' )) -- 应该可以拿到钱了，但是没配置提现地址


-- 5）BLSChange 的 validators 数量和占比(验证过的验证着并配置了提现地址)
select
    sum(case when substring(encode(withdrawalcredentials,  'hex'),1,2) != '00' then 1 else 0 end) as blsvalidatorcount,
    round(sum(case when substring(encode(withdrawalcredentials,  'hex'),1,2) != '00' then 1 else 0 end) * 1.0 / count(*), 4) as blsvalidatorrate
from validators
where activationepoch <= (select max(epoch) from epochs)

-- 6）每日抵押的以太坊数量(或者是否可以查询block_deposits表来完成)
select sum(ed.amount) / 1e9 from eth1_deposits as ed
                                     left join validators as v on  encode(ed.publickey, 'hex') = v.pubkeyhex
where
    (v.pubkeyhex is null and ed.valid_signature is true and block_numer >$昨日最大区块号)  -- 在validator中不存在
   or (v.pubkeyhex is not null and v.activationepoch > (select max(epoch) from epochs) and validatorindex > $昨日最大validatorindex) --在validator中存在但还未激活


-- 7）每日Withdraw的数量（根据slot可以计算出时间，从而可以查询每日体现数量）
select block_slot, sum(amount) / 1e9 from blocks_withdrawals where validatorindex in (
    select validatorindex from validators
    where substring(encode(withdrawalcredentials,  'hex'),1,2) != '00'
    )
group by block_slot

-- 7.1）Withdraw的数量
select * from blocks_withdrawals where validatorindex in (
    select validatorindex from validators
    where substring(encode(withdrawalcredentials,  'hex'),1,2) != '00'
    )
-- 7.2）Withdraw的数量 （第二种方式，暂时不知道和第一种方式啥区别）
select sum(amount) from blocks_withdrawals where validatorindex is null;


-- 8）等待提款数量（提取大于32个的部分）
select sum(balance - 32 * 1e9) / 1e9 from validators
where
    substring(encode(withdrawalcredentials,  'hex'),1,2) != '00'
and activationepoch <= (select max(epoch) from epochs) and (select max(epoch) from epochs) < exitepoch 
and balance > 32 * 1e9  -- 正常验证状态并配置地址

select sum(balance) / 1e9 from validators
where
    substring(encode(withdrawalcredentials,  'hex'),1,2) != '00'
and exitepoch <= (select max(epoch) from epochs) and (select max(epoch) from epochs) < withdrawableepoch  -- 退出完成等待提现状态并配置地址

select sum(balance) / 1e9 from validators
where
        substring(encode(withdrawalcredentials,  'hex'),1,2) = '00'
  and (select max(epoch) from epochs) >= withdrawableepoch  -- 退出完成等待提现状态并配置地址


-- 9) 各个状态的数量

-- 9.1）pending_deposit_count
select count(distinct ed.publickey) from eth1_deposits as ed
                                             left join validators as v on  encode(ed.publickey, 'hex') = v.pubkeyhex
where v.pubkeyhex is null and ed.valid_signature is true;

-- 9.2）deposited_count
select count(*) from validators as v
where  v.activationeligibilityepoch > (select max(epoch) from epochs)

-- 9.3）pending_count
select count(*) from validators as v
where v.activationepoch > (select max(epoch) from epochs) and v.activationeligibilityepoch <= (select max(epoch) from epochs)

-- 9.4）exiting_count
select count(*) from validators as v
where v.exitepoch != 9223372036854775807 and v.activationepoch <= (select max(epoch) from epochs) and v.exitepoch > (select max(epoch) from epochs)

-- 9.5）exited_count
select count(*) from validators as v
where v.exitepoch <= (select max(epoch) from epochs)

-- 9.6）vol_exited_count
select count(distinct bv.validatorindex) from blocks_voluntaryexits as bv
                                                  join validators as v on bv.validatorindex = v.validatorindex
where v.exitepoch <= (select max(epoch) from epochs)

-- 9.7）withdraw_finished_count
select count(*) from validators as v
where substring(encode(v.withdrawalcredentials,  'hex'),1,2) != '00' and (select max(epoch) from epochs) >= withdrawableepoch

-- 9.8）withdraw_finished_amount
select sum(amount) from (
                            select
                                validatorindex,
                                amount,
                                block_slot,
                                row_number() over(partition by validatorindex  order by block_slot desc) as rn
                            from blocks_withdrawals where validatorindex in (
                                select validatorindex from validators
                                where substring(encode(withdrawalcredentials,  'hex'),1,2) != '00' and (select max(epoch) from epochs) >= withdrawableepoch
                        )
    ) as t
where rn = 1

-- 61714 有问题

-- 可提现之后多久能拿到ETH，预估时间（最近一些提现成功的Validator的平均时间）
select avg(withdrawal_slot) / 32 from(
                                         select
                                                 block_slot - withdrawableepoch * 32 as withdrawal_slot
                                         from (
                                                  select
                                                      bw.validatorindex,
                                                      bw.block_slot,
                                                      bw.amount,
                                                      v.withdrawableepoch,
                                                      bbc.block_slot as bls_block_slot,
                                                      row_number() over(partition by bw.validatorindex  order by bw.block_slot desc) as rn
                                                  from blocks_withdrawals as bw
                                                           join validators as v on bw.validatorindex = v.validatorindex
                                                           left join blocks_bls_change as bbc on v.validatorindex = bbc.validatorindex
                                                  where
                                                          v.withdrawableepoch <= (select max(epoch) from epochs) and v.effectivebalance = 0
                                                    and (bbc.block_slot is null  or ( bbc.block_slot is not null and bbc.block_slot < v.withdrawableepoch))
                                              ) as t
                                         where rn =1
                                         order by block_slot desc
                                             limit 100
                                     ) as tt

-- 配置提现地址可提现的validators的数量
select count(*) from validators
where substring(encode(withdrawalcredentials,  'hex'),1,2) != '00' 
and (select max(epoch) from epochs) >= activationepoch
and effectivebalance > 0

	