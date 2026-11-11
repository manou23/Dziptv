-- Non-sensitive quota metadata for the encrypted profiles vault.
-- NULL means a legacy client has not yet reported a profile count.
ALTER TABLE "SyncRecord" ADD COLUMN "profileCount" INTEGER;
