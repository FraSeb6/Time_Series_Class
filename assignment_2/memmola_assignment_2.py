from pathlib import Path
def _read_excel_robust(input_path: Path, sheet_name: str | int | None):
    """Read Excel robustly, trying multiple engines with helpful guidance.

    Order of attempts:
    1) pandas default engine
    2) 'calamine' (install via: pip install pandas-calamine)
    3) 'xlrd' for legacy .xls (install via: pip install xlrd)
    """
    # 1) Try pandas default engine first (works for .xlsx when openpyxl is available)
    try:
        return pd.read_excel(input_path, sheet_name=sheet_name)
    except Exception:
        pass

    # 2) Try calamine engine (handles both .xlsx and .xls without Excel)
    try:
        return pd.read_excel(input_path, sheet_name=sheet_name, engine="calamine")
    except Exception:
        pass

    # 3) For legacy .xls, try xlrd explicitly
    if input_path.suffix.lower() == ".xls":
        try:
            return pd.read_excel(input_path, sheet_name=sheet_name, engine="xlrd")
        except Exception:
            pass

    # If all attempts fail, raise a concise, actionable error
    raise RuntimeError(
        "Could not read the Excel file. Please install one of the supported readers and retry: "
        "\n  - pip install pandas-calamine    # best all-around, supports .xls/.xlsx"
        "\n  - pip install xlrd               # for legacy .xls"
        "\nAlternatively, open the file and save/export it as .xlsx, then re-run."
    )