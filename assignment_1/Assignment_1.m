function describe_fred_series()
% DESCRIBE_FRED_SERIES
% Serie: NA000334Q, GDPDEF, B230RC0Q173SBEA
% - Legge prima da DataAssignment2.xlsx/.xls (se presente)
% - Altrimenti scarica i CSV pubblici da FRED (no API key)
% - Calcola statistiche descrittive e crea grafici (livelli e Δ%%)
%
% Output:
%   - Tabella 'summaryTable' in workspace e salvata come summary_fred.csv
%   - Figure con livelli e variazioni percentuali per ciascuna serie

    seriesCodes = {'NA000334Q','GDPDEF','B230RC0Q173SBEA'};

    % Cerca automaticamente il file Excel (xlsx o xls)
    excelCandidates = {'DataAssignment2.xlsx','DataAssignment2.xls'};
    excelFile = '';
    for c = 1:numel(excelCandidates)
        if exist(excelCandidates{c},'file') == 2
            excelFile = excelCandidates{c};
            break;
        end
    end

    allSummaries = [];
    ttAll = cell(numel(seriesCodes),1);

    for i = 1:numel(seriesCodes)
        code = seriesCodes{i};

        % ===== 1) Caricamento dati (Excel -> FRED fallback) =====
        if ~isempty(excelFile)
            try
                tt = importFromExcel(excelFile, code);
                fprintf('[%s] Importata da %s.\n', code, excelFile);
            catch ME
                warning('[%s] Lettura Excel fallita (%s). Provo FRED...', code, ME.message);
                tt = importFromFRED(code);
                fprintf('[%s] Scaricata da FRED.\n', code);
            end
        else
            tt = importFromFRED(code);
            fprintf('[%s] Scaricata da FRED.\n', code);
        end

        % ===== Pulizia base =====
        tt = sortrows(tt,'Time');
        v = tt.Value;
        keep = ~isnan(v);
        if any(keep)
            first = find(keep,1,'first');
            last  = find(keep,1,'last');
            tt = tt(first:last,:);
        end

        % ===== 2) Statistiche descrittive =====
        S = describeSeries(tt, code);
        allSummaries = [allSummaries; S]; %#ok<AGROW>
        ttAll{i} = tt;

        % ===== 3) Grafici =====
        plotSeries(tt, code, S.EstimatedFrequency);
    end

    % ===== 4) Riassunto in tabella =====
    summaryTable = struct2table(allSummaries);
    disp('--- RIEPILOGO ---');
    disp(summaryTable);

    % Salva anche su CSV
    try
        writetable(summaryTable, 'summary_fred.csv');
        fprintf('Riassunto salvato in: %s\n', fullfile(pwd,'summary_fred.csv'));
    catch ME
        warning('Impossibile salvare il CSV: %s', ME.message);
    end

    % Stampa descrizione sintetica
    fprintf('\nDESCRIZIONE SINTETICA:\n');
    for i = 1:height(summaryTable)
        r = summaryTable(i,:);
        fprintf(['%s | %s–%s | %s | n=%d, NaN=%d | ', ...
                 'min=%.4g, max=%.4g, media=%.4g, mediana=%.4g, std=%.4g | ', ...
                 'Δ ultimo periodo=%.3f%%, a/a=%.3f%%\n'], ...
            r.SeriesCode{1}, datestr(r.StartDate,'yyyy-mm-dd'), datestr(r.EndDate,'yyyy-mm-dd'), ...
            r.EstimatedFrequency{1}, r.NObs, r.NMissing, ...
            r.Min, r.Max, r.Mean, r.Median, r.Std, r.LatestQoQorMoM, r.LatestYoY);
    end
end

%% ===== helper: import from FRED (CSV pubblico) =====
function tt = importFromFRED(code)
    % FRED espone CSV "fredgraph.csv?id=CODE" (non serve API key)
    url = sprintf('https://fred.stlouisfed.org/graph/fredgraph.csv?id=%s', code);

    % Prova readtable diretto; in fallback scarica su file temporaneo
    try
        opts = weboptions('Timeout',30,'UserAgent','Mozilla/5.0');
        T = readtable(url, opts);
    catch
        try
            opts = weboptions('Timeout',30,'UserAgent','Mozilla/5.0');
            tmp = [tempname,'.csv'];
            websave(tmp, url, opts);
            T = readtable(tmp);
            delete(tmp);
        catch ME
            error('Download FRED fallito: %s', ME.message);
        end
    end

    % Colonne attese: DATE, <code>
    dateVar = 'DATE';
    if ~ismember(dateVar, T.Properties.VariableNames)
        error('CSV FRED: colonna DATE non trovata.');
    end
    if ismember(code, T.Properties.VariableNames)
        valVar = code;
    else
        % Alcune serie possono uscire con un nome diverso (p.es. suffissi)
        cand = setdiff(T.Properties.VariableNames, {'DATE'});
        if isempty(cand), error('CSV FRED: nessuna colonna valori trovata.'); end
        valVar = cand{1};
        warning('Colonna %s non trovata; uso %s.', code, valVar);
    end

    T.(dateVar) = datetime(T.(dateVar), 'InputFormat','yyyy-MM-dd');
    tt = timetable(T.(dateVar), T.(valVar), 'VariableNames', {'Value'});
    tt.Properties.DimensionNames = {'Time','Variables'};
    tt.Properties.UserData.SeriesCode = code;
end

%% ===== helper: import from Excel =====
function tt = importFromExcel(excelFile, code)
    % Prova vari layout:
    % A) Foglio chiamato come il codice, con colonne Date/Value
    % B) Primo foglio con colonna data (DATE/Date/Time) + colonna col nome uguale al codice

    % Ricava i nomi fogli in modo robusto
    sh = {};
    try
        sh = sheetnames(excelFile);
    catch
        try
            [~,sh] = xlsfinfo(excelFile);
        catch
            % lasceremo sh vuoto e leggeremo il primo foglio
        end
    end

    if ~isempty(sh) && any(strcmpi(sh, code))
        T = readtable(excelFile, 'Sheet', code);
    elseif ~isempty(sh)
        T = readtable(excelFile, 'Sheet', 1);
    else
        % Se non riesco a leggere i nomi foglio, prova a leggere diretto
        T = readtable(excelFile);
    end

    % Trova colonna data
    dateCandidates = intersect({'DATE','Date','date','Time','time'}, T.Properties.VariableNames);
    if ~isempty(dateCandidates)
        D = T.(dateCandidates{1});
        if ~isdatetime(D)
            try
                D = datetime(D);
            catch
                error('Colonna data %s non interpretabile.', dateCandidates{1});
            end
        end
    else
        % usa la prima colonna tentando la conversione
        D = T{:,1};
        if ~isdatetime(D)
            try
                D = datetime(D);
            catch
                error('Non trovo una colonna data interpretabile in %s.', excelFile);
            end
        end
    end

    % Trova colonna valori
    if ismember(code, T.Properties.VariableNames)
        V = T.(code);
    else
        % fallback: prima colonna numerica diversa dalla data
        numCols = varfun(@isnumeric, T, 'OutputFormat','uniform');
        idx = find(numCols, 1, 'first');
        if isempty(idx)
            % Se non trovo numeric, prendo la seconda colonna e converto
            if width(T) >= 2
                idx = 2;
            else
                error('Non trovo una colonna numerica per i valori della serie %s.', code);
            end
        end
        V = T{:, idx};
        warning('In Excel non trovo una colonna chiamata %s: uso %s.', ...
                 code, T.Properties.VariableNames{idx});
    end

    tt = timetable(D, double(V), 'VariableNames', {'Value'});
    tt.Properties.DimensionNames = {'Time','Variables'};
    tt.Properties.UserData.SeriesCode = code;
end

%% ===== helper: descrizione statistica =====
function S = describeSeries(tt, code)
    % Stima frequenza dalla mediana degli intervalli
    d = days(diff(tt.Time));
    if isempty(d)
        freq = 'sconosciuta';
        lagYoY = NaN;
    else
        md = median(d,'omitnan');
        if md < 15
            freq = 'giornaliera'; lagYoY = round(365/md);
        elseif md < 45
            freq = 'mensile';     lagYoY = 12;
        elseif md < 120
            freq = 'trimestrale'; lagYoY = 4;
        elseif md < 240
            freq = 'semestrale';  lagYoY = 2;
        else
            freq = 'annuale';     lagYoY = 1;
        end
    end

    V = tt.Value;
    n  = numel(V);
    nNaN = sum(isnan(V));
    stats.Min    = min(V,[],'omitnan');
    stats.Max    = max(V,[],'omitnan');
    stats.Mean   = mean(V,'omitnan');
    stats.Median = median(V,'omitnan');
    stats.Std    = std(V,'omitnan');

    % variazioni percentuali (niente Econometrics Toolbox)
    pct = @(x,lag) 100*(x./shiftvec(x,lag)-1);

    if n >= 2
        d1 = pct(V, 1);
        latestQoQ = d1(end);
    else
        latestQoQ = NaN;
    end
    if ~isnan(lagYoY) && n > lagYoY
        dYoY = pct(V, lagYoY);
        latestYoY = dYoY(end);
    else
        latestYoY = NaN;
    end

    S = struct( ...
        'SeriesCode', code, ...
        'StartDate', tt.Time(1), ...
        'EndDate',   tt.Time(end), ...
        'EstimatedFrequency', freq, ...
        'NObs', n, ...
        'NMissing', nNaN, ...
        'Min', stats.Min, ...
        'Max', stats.Max, ...
        'Mean', stats.Mean, ...
        'Median', stats.Median, ...
        'Std', stats.Std, ...
        'LatestQoQorMoM', latestQoQ, ...
        'LatestYoY', latestYoY);
end

%% ===== helper: grafici =====
function plotSeries(tt, code, freq)
    V = tt.Value;
    d1 = 100*(V./shiftvec(V,1)-1);

    figure('Name', sprintf('%s - Livello', code), 'Color','w');
    plot(tt.Time, V, 'LineWidth',1.3);
    grid on; xlabel('Data'); ylabel(code, 'Interpreter','none');
    title(sprintf('%s — livello (%s)', code, freq), 'Interpreter','none');

    figure('Name', sprintf('%s - Variazione %%', code), 'Color','w');
    bar(tt.Time, d1);
    grid on; xlabel('Data'); ylabel('Variazione % vs periodo precedente');
    title(sprintf('%s — Δ%% periodo/periodo', code), 'Interpreter','none');
end

%% ===== utility: shift di un vettore con NaN (no lagmatrix) =====
function y = shiftvec(x,k)
    % Shift in avanti di k posizioni, riempiendo con NaN (k >= 0)
    if k < 0, error('k deve essere >= 0'); end
    y = NaN(size(x));
    if k == 0
        y = x;
        return;
    end
    if numel(x) > k
        y(k+1:end,:) = x(1:end-k,:);
    end
end