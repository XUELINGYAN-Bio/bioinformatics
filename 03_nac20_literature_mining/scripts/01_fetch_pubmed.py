#!/usr/bin/env python3

"""Fetch a small, reproducible PubMed metadata table for the NAC20 project."""

from __future__ import annotations

import argparse
import csv
import json
import sys
import time
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path


PROJECT_DIR = Path(__file__).resolve().parent.parent
DEFAULT_QUERY_FILE = PROJECT_DIR / "data" / "search_query.txt"
DEFAULT_OUTPUT_FILE = PROJECT_DIR / "data" / "pubmed_records.csv"
BASE_URL = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils"


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Download a small PubMed metadata table using NCBI Entrez."
    )
    parser.add_argument(
        "--query-file",
        type=Path,
        default=DEFAULT_QUERY_FILE,
        help="Text file containing the PubMed query.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT_FILE,
        help="Output CSV path.",
    )
    parser.add_argument(
        "--retmax",
        type=int,
        default=20,
        help="Maximum number of records to fetch; default: 20.",
    )
    parser.add_argument(
        "--email",
        default="",
        help="Optional contact email sent to NCBI; not written to the CSV.",
    )
    return parser.parse_args()


def request_bytes(endpoint: str, parameters: dict[str, str]) -> bytes:
    parameters = {
        **parameters,
        "tool": "bioinformatics_portfolio_training",
    }
    encoded_parameters = urllib.parse.urlencode(parameters)
    url = f"{BASE_URL}/{endpoint}.fcgi?{encoded_parameters}"
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "bioinformatics-portfolio-training/1.0"},
    )

    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read()


def element_text(element: ET.Element | None) -> str:
    if element is None:
        return ""
    return " ".join("".join(element.itertext()).split())


def extract_year(article: ET.Element) -> str:
    year = article.findtext(".//Article/Journal/JournalIssue/PubDate/Year")
    if year:
        return year

    medline_date = article.findtext(
        ".//Article/Journal/JournalIssue/PubDate/MedlineDate",
        default="",
    )
    for token in medline_date.split():
        if len(token) == 4 and token.isdigit():
            return token
    return ""


def parse_pubmed_xml(xml_bytes: bytes, query: str) -> list[dict[str, str]]:
    root = ET.fromstring(xml_bytes)
    records: list[dict[str, str]] = []

    for pubmed_article in root.findall(".//PubmedArticle"):
        citation = pubmed_article.find("MedlineCitation")
        if citation is None:
            continue

        pmid = citation.findtext("PMID", default="")
        article = citation.find("Article")
        if article is None:
            continue

        title = element_text(article.find("ArticleTitle"))
        journal = article.findtext("Journal/Title", default="")
        year = extract_year(pubmed_article)

        authors = []
        for author in article.findall("AuthorList/Author"):
            collective_name = author.findtext("CollectiveName", default="")
            if collective_name:
                authors.append(collective_name)
                continue

            last_name = author.findtext("LastName", default="")
            initials = author.findtext("Initials", default="")
            full_name = " ".join(part for part in (last_name, initials) if part)
            if full_name:
                authors.append(full_name)

        abstract_parts = [
            element_text(abstract_element)
            for abstract_element in article.findall("Abstract/AbstractText")
        ]
        abstract = " ".join(part for part in abstract_parts if part)

        doi = ""
        for article_id in pubmed_article.findall(".//PubmedData/ArticleIdList/ArticleId"):
            if article_id.attrib.get("IdType") == "doi":
                doi = element_text(article_id)
                break

        records.append(
            {
                "pmid": pmid,
                "title": title,
                "year": year,
                "journal": journal,
                "authors": "; ".join(authors),
                "doi": doi,
                "abstract": abstract,
                "query": query,
            }
        )

    return records


def main() -> int:
    args = parse_arguments()

    if args.retmax < 1 or args.retmax > 100:
        print("--retmax must be between 1 and 100.", file=sys.stderr)
        return 2

    query_file = args.query_file.expanduser().resolve()
    output_file = args.output.expanduser().resolve()
    query = query_file.read_text(encoding="utf-8").strip()

    if not query:
        print("The query file is empty.", file=sys.stderr)
        return 2

    common_parameters = {"email": args.email} if args.email else {}
    search_parameters = {
        "db": "pubmed",
        "term": query,
        "retmode": "json",
        "retmax": str(args.retmax),
        "sort": "pub date",
        **common_parameters,
    }

    search_response = json.loads(
        request_bytes("esearch", search_parameters).decode("utf-8")
    )
    id_list = search_response["esearchresult"]["idlist"]

    if not id_list:
        print("No PubMed records matched the query.", file=sys.stderr)
        return 1

    # NCBI recommends limiting request frequency. Only two requests are made here.
    time.sleep(0.4)

    fetch_parameters = {
        "db": "pubmed",
        "id": ",".join(id_list),
        "retmode": "xml",
        **common_parameters,
    }
    records = parse_pubmed_xml(
        request_bytes("efetch", fetch_parameters),
        query,
    )

    output_file.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "pmid",
        "title",
        "year",
        "journal",
        "authors",
        "doi",
        "abstract",
        "query",
    ]

    with output_file.open("w", encoding="utf-8", newline="") as output_handle:
        writer = csv.DictWriter(output_handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(records)

    print(f"Query matched {search_response['esearchresult']['count']} records.")
    print(f"Saved {len(records)} records to {output_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

