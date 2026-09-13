/**
 * Template: sum scored radio values into a total textbox (Likert-style).
 *
 * Replace:
 *   TableName              — Forms.TableName (e.g. CustomDocumentMyScale)
 *   columnnamestartswith   — id prefix (use score if columns are ScoreFacialExpression, …)
 *   ColumnName             — total column (e.g. ScoreTotal)
 *
 * GlobalCodes: External Code 1 / Code must be numeric.
 * Requires: jQuery, UpdateAutoSaveXmlNode (SmartCare DFA runtime).
 */
$(document).ready(function () {

    function calculateTotal() {
        var total = 0;

        $('input[type="radio"][id^="RadioButton_TableName_columnnamestartswith"]:checked')
            .each(function () {
                total += parseInt($(this).val(), 10) || 0;
            });

        $('#TextBox_TableName_ColumnName').val(total);
        UpdateAutoSaveXmlNode('TableName', 'ColumnName', total);
    }

    $('input[type="radio"][id^="RadioButton_TableName_columnnamestartswith"]')
        .on('change', function () {
            calculateTotal();
        });

    // Optional when opening an existing document:
    // calculateTotal();
});
