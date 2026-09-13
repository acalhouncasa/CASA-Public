/**
 * Portable CIWA-Ar live total template for SmartCare DFA.
 *
 * Replace:
 *   table          — Forms.TableName
 *   scoredColumns  — ItemColumnName list for the 10 CIWA-Ar items
 *   displayId      — id of a span in a 5374 label, or rely on "Total Score =" text search
 *
 * If DropdownType G stores GlobalCodeId, do not treat an 8-digit val() as points.
 */
$(document).ready(function () {

    var table = 'CustomDocumentYourCIWA';
    var displayId = 'Label_' + table + '_TotalScoreDisplay';

    var scoredColumns = [
        'NauseaVomiting',
        'Anxiety',
        'ParoxysmalSweats',
        'TactileDisturbances',
        'VisualDisturbances',
        'Tremors',
        'Agitation',
        'Sensorium',
        'AuditoryDisturbances',
        'Headache'
    ];

    function dropdownFor(col) {
        return $(
            '#DropDownList_' + table + '_' + col +
            ', #DropDown_' + table + '_' + col +
            ', select[id$="_' + col + '"]'
        ).first();
    }

    function pointsFromDropdown($el) {
        if (!$el || !$el.length) {
            return 0;
        }
        var raw = $el.val();
        if (raw === null || raw === undefined || String(raw).trim() === '') {
            return 0;
        }
        var asInt = parseInt(String(raw).trim(), 10);
        if (!isNaN(asInt) && asInt >= 0 && asInt <= 7 && String(raw).trim().length <= 1) {
            return asInt;
        }
        var $opt = $el.find('option:selected');
        if ($opt.length) {
            var label = String($opt.text() || '').replace(/^\s+/, '');
            var fromName = parseInt(label, 10);
            if (!isNaN(fromName) && fromName >= 0 && fromName <= 7) {
                return fromName;
            }
        }
        return 0;
    }

    function totalScoreText(total) {
        if (total > 20) {
            return 'severe withdrawal';
        }
        if (total >= 10 && total <= 19) {
            return 'mild to moderate withdrawal';
        }
        if (total >= 0 && total <= 9) {
            return 'absent or minimal withdrawal';
        }
        return 'mild to moderate withdrawal';
    }

    function setDisplay(total) {
        var text = String(total) + ': ' + totalScoreText(total);
        var $disp = $('#' + displayId);
        if ($disp.length) {
            $disp.text(text);
            return;
        }
        $('td').filter(function () {
            return String($(this).text() || '').replace(/\s+/g, ' ').indexOf('Total Score =') >= 0;
        }).first().each(function () {
            var $cell = $(this);
            var $next = $cell.next('td');
            if ($next.length) {
                $next.text(text);
            } else {
                $cell.text('Total Score = ' + text);
            }
        });
    }

    function calculateTotal() {
        var total = 0;
        var i;
        for (i = 0; i < scoredColumns.length; i++) {
            total += pointsFromDropdown(dropdownFor(scoredColumns[i]));
        }
        setDisplay(total);
    }

    scoredColumns.forEach(function (col) {
        $('#DropDownList_' + table + '_' + col +
            ', #DropDown_' + table + '_' + col +
            ', select[id$="_' + col + '"]')
            .on('change', calculateTotal);
    });

    calculateTotal();
});
