-- Migracja dla juz istniejacej bazy (init SQL odpala sie tylko przy pustym wolumenie).
-- Uruchom raz:
--   docker exec -i local4word6-projectterrific-db mysql -ufivem -pfivem_local projectterrific < docker/mariadb/migrations/2026-09-02-audyt.sql

-- AUDIT pkt 21: SELECT * FROM phone_gallery WHERE citizenid = ? bez indeksu (log: "qb-phone took 361 ms")
ALTER TABLE `phone_gallery`
  ADD COLUMN IF NOT EXISTS `id` int(10) NOT NULL AUTO_INCREMENT PRIMARY KEY FIRST,
  ADD INDEX IF NOT EXISTS `idx_phone_gallery_citizenid` (`citizenid`);

-- AUDIT_EKONOMIA: brak kolumn wymaganych przez qb-banking (createbusinessAccount)
ALTER TABLE `bank_accounts`
  ADD COLUMN IF NOT EXISTS `account_number` varchar(50) DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `sort_code` varchar(20) DEFAULT NULL;
