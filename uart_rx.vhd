library ieee;
use ieee.std_logic_1164.all;

entity uart_rx_core is
    generic (
        CLK_HZ    : positive := 50_000_000;
        BAUD_RATE : positive := 115_200
    );
    port (
        clk         : in  std_logic;
        reset       : in  std_logic;
        rx_in       : in  std_logic;

        data_out    : out std_logic_vector(7 downto 0);
        byte_valid  : out std_logic;
        frame_error : out std_logic
    );
end entity uart_rx_core;

architecture rtl of uart_rx_core is

    constant CLKS_PER_BIT : positive := CLK_HZ / BAUD_RATE;
    constant HALF_BIT     : positive := CLKS_PER_BIT / 2;

    type state_type is (IDLE, START_BIT, DATA_BITS, STOP_BIT);
    signal state : state_type := IDLE;

    signal rx_meta : std_logic := '1';
    signal rx_sync : std_logic := '1';

    signal bit_timer : integer range 0 to CLKS_PER_BIT - 1 := 0;
    signal bit_index : integer range 0 to 7 := 0;

    signal shift_reg : std_logic_vector(7 downto 0) :=
        (others => '0');

begin

    process (clk)
    begin
        if rising_edge(clk) then
            rx_meta <= rx_in;
            rx_sync <= rx_meta;

            byte_valid  <= '0';
            frame_error <= '0';

            if reset = '1' then
                rx_meta   <= '1';
                rx_sync   <= '1';
                state     <= IDLE;
                bit_timer <= 0;
                bit_index <= 0;
                shift_reg <= (others => '0');
                data_out  <= (others => '0');

            else
                case state is

                    when IDLE =>
                        if rx_sync = '0' then
                            bit_timer <= HALF_BIT - 1;
                            state <= START_BIT;
                        end if;

                    when START_BIT =>
                        if bit_timer = 0 then
                            if rx_sync = '0' then
                                bit_timer <= CLKS_PER_BIT - 1;
                                bit_index <= 0;
                                state <= DATA_BITS;
                            else
                                state <= IDLE;
                            end if;
                        else
                            bit_timer <= bit_timer - 1;
                        end if;

                    when DATA_BITS =>
                        if bit_timer = 0 then
                            shift_reg(bit_index) <= rx_sync;
                            bit_timer <= CLKS_PER_BIT - 1;

                            if bit_index = 7 then
                                state <= STOP_BIT;
                            else
                                bit_index <= bit_index + 1;
                            end if;
                        else
                            bit_timer <= bit_timer - 1;
                        end if;

                    when STOP_BIT =>
                        if bit_timer = 0 then
                            if rx_sync = '1' then
                                data_out   <= shift_reg;
                                byte_valid <= '1';
                            else
                                frame_error <= '1';
                            end if;

                            state <= IDLE;
                        else
                            bit_timer <= bit_timer - 1;
                        end if;

                end case;
            end if;
        end if;
    end process;

end architecture rtl;
