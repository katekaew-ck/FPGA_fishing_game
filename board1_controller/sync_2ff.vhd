library ieee;
use ieee.std_logic_1164.all;

entity sync_2ff is
    generic (
        WIDTH : positive := 4
    );
    port (
        clk      : in  std_logic;
        reset    : in  std_logic;
        async_in : in  std_logic_vector(WIDTH - 1 downto 0);
        sync_out : out std_logic_vector(WIDTH - 1 downto 0)
    );
end entity sync_2ff;

architecture rtl of sync_2ff is

    signal first_ff  : std_logic_vector(WIDTH - 1 downto 0);
    signal second_ff : std_logic_vector(WIDTH - 1 downto 0);

begin

    process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                first_ff  <= (others => '1');
                second_ff <= (others => '1');
            else
                first_ff  <= async_in;
                second_ff <= first_ff;
            end if;
        end if;
    end process;

    sync_out <= second_ff;

end architecture rtl;
