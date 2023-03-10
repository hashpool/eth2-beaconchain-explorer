-- 1）总锁仓金额
select sum(amount) from (
                            select totalvalidatorbalance / 1e9 as amount  from epochs where epoch = (select max(epoch) from epochs)
                            union
                            select sum(ed.amount) / 1e9 from eth1_deposits as ed
                                                                 left join validators as v on  encode(ed.publickey, 'hex') = v.pubkeyhex
                            where
                                (v.pubkeyhex is null and ed.valid_signature is true)  -- 在validator中不存在
                               or (v.pubkeyhex is not null and v.activationepoch > (select max(epoch) from epochs)) --在validator中存在但还未激活
                               or (v.pubkeyhex is not null and v.exitepoch <= (select max(epoch) from epochs) and (select max(epoch) from epochs) < v.withdrawableepoch) --已退出，但是还没到账的(这个数据不准，需要根据validator查询才是最准确的)
                               or (v.pubkeyhex is not null and v.exitepoch <= (select max(epoch) from epochs) and (select max(epoch) from epochs) >= v.withdrawableepoch and substring(encode(withdrawalcredentials,  'hex'),1,2) = '00' ) --已完成退出，但未配置提款地址(这个数据不准，需要根据validator查询才是最准确的)
                        ) as t


-- 2) 活跃的Validators
select count(*) from validators
where activationepoch <= (select max(epoch) from epochs) and (select max(epoch) from epochs) < exitepoch

-- 3) deposited和pending的Validators
select distinct validatorindex,encode(ed.publickey, 'hex') from eth1_deposits as ed
                                                                    left join validators as v on  encode(ed.publickey, 'hex') = v.pubkeyhex
where
    (v.pubkeyhex is null and ed.valid_signature is true)  -- 在validator中不存在
   or
    (v.pubkeyhex is not null and v.activationepoch > (select max(epoch) from epochs)) --在validator中存在但还未激活


-- 4）已经申请退出等到Withdraw提款的所有validator的数量和金额（自愿和强制的都有）
select count(*), sum(balance) from validators
where exitepoch != 9223372036854775807
and (
	(select max(epoch) from epochs) < exitepoch  --已申请，还未到 exitepoch
	or
	((select max(epoch) from epochs) >= exitepoch and (select max(epoch) from epochs) <  withdrawableepoch ) --到达exitepoch，但还没拿到钱
	or
	((select max(epoch) from epochs) > withdrawableepoch and substring(encode(withdrawalcredentials,  'hex'),1,2) = '00' ) -- 应该可以拿到钱了，但是没配置提现地址


-- 5）BLSChange 的 validators 数量和占比
select
	round(sum(case when substring(encode(withdrawalcredentials,  'hex'),1,2) != '00' then 1 else 0 end) * 1.0 / count(*), 4)
from validators
where activationepoch <= (select max(epoch) from epochs) and (select max(epoch) from epochs) < exitepoch

-- 6）抵押的以太坊数量
select sum(ed.amount) / 1e9 from eth1_deposits as ed
left join validators as v on  encode(ed.publickey, 'hex') = v.pubkeyhex
where
	(v.pubkeyhex is null and ed.valid_signature is true)  -- 在validator中不存在
	or (v.pubkeyhex is not null and v.activationepoch > (select max(epoch) from epochs)) --在validator中存在但还未激活

-- 7）Withdraw的数量
select sum(Balance) from validators
where substring(encode(withdrawalcredentials,  'hex'),1,2) != '00'
  and (select max(epoch) from epochs) >= e.withdrawableepoch
