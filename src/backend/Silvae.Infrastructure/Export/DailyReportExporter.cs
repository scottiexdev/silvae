using System.Globalization;
using System.Text;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;
using Silvae.Application.DailyReports;

namespace Silvae.Infrastructure.Export;

/// <summary>
/// Rendicontazione in formato tabellare e stampabile. Una riga per persona e
/// per giornata, come il foglio presenze che sostituisce.
/// </summary>
public static class DailyReportExporter
{
    private static readonly string[] Headers =
    [
        "Data",
        "Commessa",
        "Descrizione commessa",
        "Cantiere",
        "Descrizione cantiere",
        "Operatore",
        "Ore",
        "Stato",
        "Conferma",
        "Lavorazioni",
        "Non conformità",
        "Note",
    ];

    /// <summary>
    /// Il PDF sta su una pagina orizzontale e lascia fuori le colonne che si
    /// leggono meglio nel foglio di calcolo.
    /// </summary>
    private static readonly string[] PdfHeaders =
    [
        "Data",
        "Commessa",
        "Cantiere",
        "Descrizione",
        "Operatore",
        "Ore",
        "Stato",
        "Lavorazioni",
        "Non conformità",
    ];

    /// <summary>
    /// CSV con separatore punto e virgola e BOM: è come Excel in italiano si
    /// aspetta di trovarlo, e senza BOM le lettere accentate arrivano rotte.
    /// </summary>
    public static byte[] ToCsv(IReadOnlyList<DailyReportExportRow> rows)
    {
        ArgumentNullException.ThrowIfNull(rows);

        var builder = new StringBuilder();
        builder.AppendLine(string.Join(';', Headers));

        foreach (var row in rows)
        {
            builder.AppendLine(string.Join(';', new[]
            {
                row.ReportDate.ToString("dd/MM/yyyy", CultureInfo.InvariantCulture),
                row.JobOrderCode,
                row.JobOrderName,
                row.WorksiteCode,
                row.WorksiteName,
                row.DisplayName,
                row.Hours.ToString("0.00", CultureInfo.GetCultureInfo("it-IT")),
                row.Status,
                row.Signature,
                row.Activities,
                row.SafetyFindings,
                row.Notes,
            }.Select(EscapeCsv)));
        }

        return new UTF8Encoding(encoderShouldEmitUTF8Identifier: true)
            .GetBytes(builder.ToString());
    }

    public static byte[] ToPdf(
        IReadOnlyList<DailyReportExportRow> rows,
        string organizationName,
        DateTimeOffset generatedAt)
    {
        ArgumentNullException.ThrowIfNull(rows);

        var totalHours = rows.Sum(row => row.Hours);

        return Document.Create(container => container.Page(page =>
        {
            page.Size(PageSizes.A4.Landscape());
            page.Margin(1, Unit.Centimetre);
            page.DefaultTextStyle(text => text.FontSize(8));

            page.Header().Column(header =>
            {
                header.Item().Text(organizationName).FontSize(14).Bold();
                header.Item().Text(string.Create(
                    CultureInfo.GetCultureInfo("it-IT"),
                    $"Rendicontazione · {rows.Count} righe · {totalHours:0.00} ore · " +
                    $"estratta il {generatedAt.LocalDateTime:dd/MM/yyyy HH:mm}"))
                    .FontSize(9)
                    .FontColor(Colors.Grey.Darken1);
            });

            page.Content().PaddingVertical(8).Table(table =>
            {
                table.ColumnsDefinition(columns =>
                {
                    columns.ConstantColumn(50);
                    columns.ConstantColumn(50);
                    columns.ConstantColumn(60);
                    columns.RelativeColumn(2);
                    columns.RelativeColumn(2);
                    columns.ConstantColumn(30);
                    columns.ConstantColumn(50);
                    columns.RelativeColumn(3);
                    columns.RelativeColumn(2);
                });

                table.Header(header =>
                {
                    foreach (var title in PdfHeaders)
                    {
                        header.Cell()
                            .BorderBottom(1)
                            .PaddingVertical(3)
                            .Text(title)
                            .Bold();
                    }
                });

                foreach (var row in rows)
                {
                    Cell(table, row.ReportDate.ToString(
                        "dd/MM/yyyy",
                        CultureInfo.InvariantCulture));
                    Cell(table, row.JobOrderCode);
                    Cell(table, row.WorksiteCode);
                    Cell(table, row.WorksiteName);
                    Cell(table, row.DisplayName);
                    Cell(table, row.Hours.ToString(
                        "0.00",
                        CultureInfo.GetCultureInfo("it-IT")));
                    Cell(table, row.Status);
                    Cell(table, row.Activities);
                    Cell(table, row.SafetyFindings);
                }
            });

            page.Footer().AlignRight().Text(text =>
            {
                text.CurrentPageNumber();
                text.Span(" / ");
                text.TotalPages();
            });
        })).GeneratePdf();
    }

    private static void Cell(TableDescriptor table, string value)
    {
        table.Cell()
            .BorderBottom(0.5f)
            .BorderColor(Colors.Grey.Lighten2)
            .PaddingVertical(2)
            .Text(value);
    }

    /// <summary>
    /// Un punto e virgola dentro una descrizione sposterebbe tutte le colonne
    /// successive di una posizione.
    /// </summary>
    private static string EscapeCsv(string value)
    {
        var normalized = value.Replace('\r', ' ').Replace('\n', ' ');
        return normalized.Contains(';', StringComparison.Ordinal) ||
            normalized.Contains('"', StringComparison.Ordinal)
            ? '"' + normalized.Replace("\"", "\"\"", StringComparison.Ordinal) + '"'
            : normalized;
    }
}
