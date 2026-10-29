library ieee;
use ieee.std_logic_1164.all;

entity uart_tx_core is
    generic (
        CLK_HZ    : positive := 50_000_000;
        BAUD_RATE : positive := 115_200
    );
    port (
        clk      : in  std_logic;
        reset    : in  std_logic;

        data_in  : in  std_logic_vector(7 downto 0);
        tx_start : in  std_logic;

        tx_out   : out std_logic;
        tx_busy  : out std_logic;
        tx_done  : out std_logic
    );
end entity uart_tx_core;

architecture rtl of uart_tx_core is

    constant CLKS_PER_BIT : positive := CLK_HZ / BAUD_RATE;

    type state_type is (
        IDLE,
        START_BIT,
        DATA_BITS,
        STOP_BIT
    );

    signal state : state_type := IDLE;

    signal baud_counter : integer range 0 to CLKS_PER_BIT - 1 := 0;
    signal bit_index    : integer range 0 to 7 := 0;

    signal data_register : std_logic_vector(7 downto 0) :=
        (others => '0');

begin

    with state select
        tx_out <=
            '1'                      when IDLE,
            '0'                      when START_BIT,
            data_register(bit_index) when DATA_BITS,
            '1'                      when STOP_BIT;

    tx_busy <= '0' when state = IDLE else '1';

    process (clk)
    begin
        if rising_edge(clk) then

            tx_done <= '0';

            if reset = '1' then
                state         <= IDLE;
                baud_counter  <= 0;
                bit_index     <= 0;
                data_register <= (others => '0');

            else
                case state is

                    when IDLE =>
                        baud_counter <= 0;
                        bit_index    <= 0;

                        if tx_start = '1' then
                            data_register <= data_in;
                            state <= START_BIT;
                        end if;

                    when START_BIT =>
                        if baud_counter = CLKS_PER_BIT - 1 then
                            baud_counter <= 0;
                            bit_index <= 0;
                            state <= DATA_BITS;
                        else
                            baud_counter <= baud_counter + 1;
                        end if;

                    when DATA_BITS =>
                        if baud_counter = CLKS_PER_BIT - 1 then
                            baud_counter <= 0;

                            if bit_index = 7 then
                                bit_index <= 0;
                                state <= STOP_BIT;
                            else
                                bit_index <= bit_index + 1;
                            end if;

                        else
                            baud_counter <= baud_counter + 1;
                        end if;

                    when STOP_BIT =>
                        if baud_counter = CLKS_PER_BIT - 1 then
                            baud_counter <= 0;
                            state <= IDLE;
                            tx_done <= '1';
                        else
                            baud_counter <= baud_counter + 1;
                        end if;

                end case;
            end if;
        end if;
    end process;

end architecture rtl;
