% DESCRIPTION OF VARIABLES (FRED - Federal Reserve Bank of St. Louis)
%
% observation_date:
%   Observation date (monthly frequency).
%
% GASREGW:
%   Average retail price of Regular gasoline (all formulations), U.S.
%   Units: U.S. dollars per gallon (USD/gallon).
%   Frequency: monthly, NOT seasonally adjusted.
%   Source: FRED (U.S. Regular All Formulations Gas Price).
%
% CPIAUCSL:
%   Consumer Price Index for All Urban Consumers (CPI-U),
%   all items, base 1982–84 = 100.
%   Frequency: monthly, seasonally adjusted.
%   Source: FRED (Consumer Price Index for All Urban Consumers).
%
% DERIVED VARIABLES:
%   log_gas  = log(GASREGW);              % logarithm of nominal gas price
%   dlog_gas = diff(log_gas);             % monthly % change
%   log_cpi  = log(CPIAUCSL);             % logarithm of CPI index
%   infl_m   = diff(log_cpi);             % monthly inflation
%   real_gas = GASREGW ./ CPIAUCSL * 100; % real gasoline price

%========= SLIDE 1 =========

% Load the data
data = readtable('/Users/memmo/Documents/GitHub/Time_Series_Class/assignment_2/gasoline.xls');

% Extract variables
gas_nominal = data.GASREGW;     % Nominal gasoline price (USD/gallon)
cpi = data.CPIAUCSL;            % Consumer Price Index (base 1982–84 = 100)

% Create the real price of gasoline
real_gas = gas_nominal ./ cpi * 100;

% Add to the table
data.Real_Gasoline = real_gas;

% Display the first few rows
head(data)

%========= SLIDE 2 =========

% plot the nominal vs. real price
figure;
plot(data.observation_date, data.GASREGW, 'b', 'DisplayName', 'Gasoline nominal price');
hold on;
plot(data.observation_date, data.Real_Gasoline, 'r', 'DisplayName', 'Gasoline real price');
title('Nominal price vs Real price of gasoline');
xlabel('Data');

ylabel('USD per gallon');
legend('Location', 'best');
grid on;

%% ========= SLIDE 3: ACF of log real gasoline price =========

% 1. Construct the real gasoline price if not already done
% (skip this if data.Real_Gasoline already exists)
if ~ismember("Real_Gasoline", string(data.Properties.VariableNames))
    data.Real_Gasoline = data.GASREGW ./ data.CPIAUCSL * 100;
end

% 2. Define y_t = log(real gasoline price)
data.y = log(data.Real_Gasoline);

% 3. Restrict the sample: from first observation up to Dec 2014
end_date = datetime(2014,12,1);  % December 2014
idx_sample = data.observation_date <= end_date;

y_sample = data.y(idx_sample);

% 4. Construct the first difference: Δy_t = y_t - y_{t-1}
dy_sample = diff(y_sample);

% 5. Plot the ACF of y_t (log real price)
figure;
autocorr(y_sample);
title('Sample ACF of y_t = log(Real Gasoline Price)');

% 6. Plot the ACF of Δy_t
figure;
autocorr(dy_sample);
title('Sample ACF of \Delta y_t = y_t - y_{t-1}');

%% ========= SLIDE 4: AR(1) on y_t and Δy_t =========

% 0. Make sure Real_Gasoline exists
if ~ismember("Real_Gasoline", string(data.Properties.VariableNames))
    data.Real_Gasoline = data.GASREGW ./ data.CPIAUCSL * 100;
end

% 1. Define y_t = log(real gasoline price)
data.y = log(data.Real_Gasoline);

% 2. Restrict to the sample up to Dec 2014
end_date = datetime(2014,12,1);
idx_sample = data.observation_date <= end_date;

y_sample = data.y(idx_sample);

% 3. Build first difference Δy_t
dy_sample = diff(y_sample);  % Δy_t = y_t - y_{t-1}

%% -------- AR(1) for y_t --------
% Model: y_t = alpha + phi * y_{t-1} + e_t

y_now  = y_sample(2:end);      % y_t
y_lag  = y_sample(1:end-1);    % y_{t-1}

X_level = [ones(length(y_lag),1) y_lag];  % constant + lag
b_level = X_level \ y_now;                % OLS

alpha_level = b_level(1);   % intercept alpha
phi_level   = b_level(2);   % AR(1) coefficient phi

%% -------- AR(1) for Δy_t --------
% Model: Δy_t = gamma + rho * Δy_{t-1} + u_t

dy_now = dy_sample(2:end);        % Δy_t
dy_lag = dy_sample(1:end-1);      % Δy_{t-1}

X_diff = [ones(length(dy_lag),1) dy_lag]; % constant + lag
b_diff = X_diff \ dy_now;                 % OLS

gamma_diff = b_diff(1);   % intercept gamma
rho_diff   = b_diff(2);   % AR(1) coefficient rho

%% -------- Report the AR(1) coefficients --------
fprintf('AR(1) on levels (y_t):\n');
fprintf('  phi (coefficient on y_{t-1}) = %.4f\n\n', phi_level);

fprintf('AR(1) on first differences (Δy_t):\n');
fprintf('  rho (coefficient on Δy_{t-1}) = %.4f\n', rho_diff);

%% ========= SLIDE 5: Recursive 1-step-ahead forecasts =========

% Ensure real gasoline price exists
if ~ismember("Real_Gasoline", string(data.Properties.VariableNames))
    data.Real_Gasoline = data.GASREGW ./ data.CPIAUCSL * 100;
end

% Define y_t = log(real gasoline price)
data.y = log(data.Real_Gasoline);

% Define the split date: end of estimation sample (Dec 2014)
splitDate = datetime(2014,12,1);

% Full series and dates
y_full = data.y;
t_full = data.observation_date;

% Index for in-sample (estimation) and out-of-sample (forecast evaluation)
idx_in  = t_full <= splitDate;   % up to Dec 2014
idx_out = t_full > splitDate;    % after Dec 2014

y_in  = y_full(idx_in);          % estimation sample initial
y_out = y_full(idx_out);         % true future values (for comparison)
t_out = t_full(idx_out);         % forecast dates

T_in  = length(y_in);            % number of obs up to Dec 2014
T_tot = length(y_full);          % total number of obs

% Preallocate forecast vectors
f_rw      = NaN(size(y_out)); % random walk forecasts
f_arima10 = NaN(size(y_out)); % ARIMA(1,1,0)
f_arima01 = NaN(size(y_out)); % ARIMA(0,1,1)
f_arima11 = NaN(size(y_out)); % ARIMA(1,1,1)

% Recursive / expanding estimation
for h = 1:length(y_out)

    % Use data up to time T_in + h - 1 for estimation
    y_est = y_full(1 : T_in + h - 1);

    % ------------------
    % 1) Random Walk (no drift)
    % y_{t+1|t} = y_t
    f_rw(h) = y_est(end);

    % ------------------
    % 2) ARIMA(1,1,0)
    % This means: diff(y_t) follows AR(1)
    M10 = arima(1,1,0);  % default: no constant in diff eq unless Constant is set
    est10 = estimate(M10, y_est, 'Display', 'off');
    f_arima10(h) = forecast(est10, 1, y_est);  % 1-step-ahead forecast

    % ------------------
    % 3) ARIMA(0,1,1)
    % This means: diff(y_t) follows MA(1)
    M01 = arima(0,1,1);
    est01 = estimate(M01, y_est, 'Display', 'off');
    f_arima01(h) = forecast(est01, 1, y_est);

    % ------------------
    % 4) ARIMA(1,1,1)
    % This means: diff(y_t) follows ARMA(1,1)
    M11 = arima(1,1,1);
    est11 = estimate(M11, y_est, 'Display', 'off');
    f_arima11(h) = forecast(est11, 1, y_est);

end

% For convenience, put forecasts in a table
ForecastTable = table( ...
    t_out, ...
    y_out, ...
    f_rw, ...
    f_arima10, ...
    f_arima01, ...
    f_arima11, ...
    'VariableNames', { ...
        'Date', ...
        'Actual_y', ...
        'Forecast_RW', ...
        'Forecast_ARIMA_110', ...
        'Forecast_ARIMA_011', ...
        'Forecast_ARIMA_111' ...
    } ...
);

head(ForecastTable)

%% (Optional) Plot actual vs forecasts from one model, e.g. RW vs ARIMA(1,1,1)
figure;
plot(ForecastTable.Date, ForecastTable.Actual_y, 'k', 'LineWidth', 1.2, 'DisplayName', 'Actual y_t');
hold on;
plot(ForecastTable.Date, ForecastTable.Forecast_RW, 'b--', 'LineWidth', 1.2, 'DisplayName', 'RW Forecast');
plot(ForecastTable.Date, ForecastTable.Forecast_ARIMA_111, 'r--', 'LineWidth', 1.2, 'DisplayName', 'ARIMA(1,1,1) Forecast');
xlabel('Date');
ylabel('log(Real Gasoline Price)');
title('Recursive 1-step-ahead forecasts');
legend('Location', 'best');
grid on;

%% ========= SLIDE 6: Convert forecasts back to levels =========
% Recall:
% y_t = log(Real_Gasoline_t)
% So Real_Gasoline_t = exp(y_t)

% 1. Actual real gasoline price in levels for the out-of-sample period
Actual_level = exp(ForecastTable.Actual_y);

% 2. Forecasts in levels
Forecast_RW_level      = exp(ForecastTable.Forecast_RW);
Forecast_ARIMA_110_lvl = exp(ForecastTable.Forecast_ARIMA_110);
Forecast_ARIMA_011_lvl = exp(ForecastTable.Forecast_ARIMA_011);
Forecast_ARIMA_111_lvl = exp(ForecastTable.Forecast_ARIMA_111);

% 3. Add these to the table
ForecastTable.Actual_Level              = Actual_level;
ForecastTable.Forecast_RW_Level         = Forecast_RW_level;
ForecastTable.Forecast_ARIMA_110_Level  = Forecast_ARIMA_110_lvl;
ForecastTable.Forecast_ARIMA_011_Level  = Forecast_ARIMA_011_lvl;
ForecastTable.Forecast_ARIMA_111_Level  = Forecast_ARIMA_111_lvl;

head(ForecastTable)

%% 4. Plot actual vs forecasts in levels (real gasoline price)
figure;
plot(ForecastTable.Date, ForecastTable.Actual_Level, 'k', 'LineWidth', 1.2, ...
    'DisplayName', 'Actual Real Gasoline Price');
hold on;
plot(ForecastTable.Date, ForecastTable.Forecast_RW_Level, 'b--', 'LineWidth', 1.2, ...
    'DisplayName', 'RW Forecast');
plot(ForecastTable.Date, ForecastTable.Forecast_ARIMA_111_Level, 'r--', 'LineWidth', 1.2, ...
    'DisplayName', 'ARIMA(1,1,1) Forecast');
xlabel('Date');
ylabel('Real Gasoline Price (USD per gallon, 1982–84 dollars)');
title('Recursive 1-step-ahead forecasts in levels');
legend('Location','best');
grid on;


%% ========= SLIDE 7: Forecast evaluation (MSFE) =========

% --- MSFE in logs (y_t = log(real price)) ---
errors_RW_log  = ForecastTable.Actual_y - ForecastTable.Forecast_RW;
errors_110_log = ForecastTable.Actual_y - ForecastTable.Forecast_ARIMA_110;
errors_011_log = ForecastTable.Actual_y - ForecastTable.Forecast_ARIMA_011;
errors_111_log = ForecastTable.Actual_y - ForecastTable.Forecast_ARIMA_111;

MSFE_RW_log  = mean(errors_RW_log.^2);
MSFE_110_log = mean(errors_110_log.^2);
MSFE_011_log = mean(errors_011_log.^2);
MSFE_111_log = mean(errors_111_log.^2);

fprintf('\nMSFE (log of real gasoline price):\n');
fprintf(' Random Walk:     %.6f\n', MSFE_RW_log);
fprintf(' ARIMA(1,1,0):    %.6f\n', MSFE_110_log);
fprintf(' ARIMA(0,1,1):    %.6f\n', MSFE_011_log);
fprintf(' ARIMA(1,1,1):    %.6f\n', MSFE_111_log);

% --- MSFE in levels (real price) ---
errors_RW_lvl  = ForecastTable.Actual_Level - ForecastTable.Forecast_RW_Level;
errors_110_lvl = ForecastTable.Actual_Level - ForecastTable.Forecast_ARIMA_110_Level;
errors_011_lvl = ForecastTable.Actual_Level - ForecastTable.Forecast_ARIMA_011_Level;
errors_111_lvl = ForecastTable.Actual_Level - ForecastTable.Forecast_ARIMA_111_Level;

MSFE_RW_lvl  = mean(errors_RW_lvl.^2);
MSFE_110_lvl = mean(errors_110_lvl.^2);
MSFE_011_lvl = mean(errors_011_lvl.^2);
MSFE_111_lvl = mean(errors_111_lvl.^2);

fprintf('\nMSFE (real gasoline price levels):\n');
fprintf(' Random Walk:     %.6f\n', MSFE_RW_lvl);
fprintf(' ARIMA(1,1,0):    %.6f\n', MSFE_110_lvl);
fprintf(' ARIMA(0,1,1):    %.6f\n', MSFE_011_lvl);
fprintf(' ARIMA(1,1,1):    %.6f\n', MSFE_111_lvl);