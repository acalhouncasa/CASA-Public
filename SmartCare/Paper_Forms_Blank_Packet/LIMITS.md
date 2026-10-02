# Limits — what this pack is not

## Out of scope

| Topic | Why |
|-------|-----|
| **Core Assessment** (assessment tab triggers, Assessment Groups, attached `TableList` docs with **0** FormItems) | Tabs and labels often come from triggers + RDL static text, not one FormItems tree |
| **Fillable AcroForm overlay** | Optional product; page-indexed overlays break if you change cover page-breaks |
| **SmartCare Rx / ePrescribe New Order** | Often no DocumentCode; build from a screenshot if you need a blank |
| **FormLab / external CSV paper forms** | Different source grain |
| **Creating or editing the on-screen DFA** | Use [DFA_From_PDF/](../DFA_From_PDF/) or your normal DFA workflow |
| **Credentials, VPN, agency hosts** | Not published here |

## If your document is Core Assessment–like

You need a separate builder that:

1. Reads `DocumentCodeAssessmentTabTriggers` (and Assessment Group filters your org uses)
2. Pulls RDL / attached-document labels where FormItems are empty
3. Optionally keeps a dedicated cover page if you add a fillable overlay later

Do not force that onto the FormItems starter in this folder.

## What Streamline already gives you

Saved-chart PDFs (View Document) and some vendor “template” RDL names still require a chart document version. They are not a generic blank handout for the waiting room.
