defmodule Oli.Repo.Migrations.AddCrockfordBase32EncodeFunction do
  use Ecto.Migration

  def up do

    execute """
    CREATE OR REPLACE FUNCTION crockford_base32_encode(number BIGINT) RETURNS TEXT AS $$
    DECLARE
      alphabet TEXT := '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
      encoded TEXT := '';
      remainder INT;
    BEGIN
      IF number = 0 THEN
        RETURN '0';
      END IF;
      WHILE number > 0 LOOP
        remainder := number % 32;
        encoded := SUBSTRING(alphabet FROM remainder+1 FOR 1) || encoded;
        number := number / 32;
      END LOOP;
      RETURN encoded;
    END;
    $$ LANGUAGE plpgsql IMMUTABLE STRICT;
    """
  end

  def down do
    execute "DROP FUNCTION IF EXISTS crockford_base32_encode(BIGINT);"
  end
end
