# HP Key: accents for text written without them

Select Vietnamese written without accents in any app ("hien tai nguoi dung nay khong hoat dong") and HP Key shows
it with accents in a bubble above the selection ("hiện tại người dùng này không hoạt động"). Code:
`App/Model/AccentRestorer.swift` (the model and the decoder) and `App/Model/SelectionAccents.swift` (reading the
selection through Accessibility and the bubble). Setting: Gõ tiếng Việt › Hiện dấu khi bôi đen.

## Rebuild the model

Download the sentence files of two Leipzig corpora (CC BY 4.0) from
https://wortschatz.uni-leipzig.de/en/download/Vietnamese: `vie_news_2022_300K` and `vie-vn_web_2015_300K`.

```sh
python3 build_model.py ../../App/Resources/AccentModel.bin /tmp/heldout.txt \
  vie_news_2022_300K-sentences.txt vie-vn_web_2015_300K-sentences.txt
```

Every 20th sentence is held out and written to `/tmp/heldout.txt`; it is never counted.

## Measure

```sh
./eval.sh ../../App/Resources/AccentModel.bin /tmp/heldout.txt            # held-out news and web text
./eval.sh ../../App/Resources/AccentModel.bin ../autoswitch/sim/corpus/chat_messages.txt 5   # chat mixing English
```

Results on 2026-11-18 (all accents removed, then restored; tone placement hoà/hòa counted as the same):

| Text | Words with accents restored exactly | Words without accents left alone |
|---|---|---|
| 20,000 held-out news/web sentences | 95.8% | 96.2% |
| 1,869 chat messages mixing English | 88.1% | 96.6% |
