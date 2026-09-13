/**
 * Template: count Yes answers on RADIOYN radios (not Likert points).
 *
 * Replace TableName and list your Yes/No column names.
 * Do not parseInt Y/N values as points.
 *
 * Element ids are typically RadioButton_<TableName>_<ColumnName>.
 */
$(document).ready(function () {

    var table = 'CustomDocumentYourForm';
    var yesNoColumns = ['Item01', 'Item02', 'Item03'];
    var totalColumn = 'ScoreTotal';

    function isYes($el) {
        if (!$el || !$el.length) return false;
        var v = String($el.filter(':checked').val() || '').toUpperCase();
        return v === 'Y' || v === 'YES';
    }

    function radio(col) {
        return $('input[type="radio"][id="RadioButton_' + table + '_' + col + '"]');
    }

    function calculateTotal() {
        var total = 0;
        var i;
        for (i = 0; i < yesNoColumns.length; i++) {
            if (isYes(radio(yesNoColumns[i]))) {
                total += 1;
            }
        }
        var $box = $('#TextBox_' + table + '_' + totalColumn + ', #Integer_' + table + '_' + totalColumn');
        $box.val(total);
        UpdateAutoSaveXmlNode(table, totalColumn, total);
    }

    yesNoColumns.forEach(function (col) {
        radio(col).on('change', calculateTotal);
    });

    calculateTotal();
});
