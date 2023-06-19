#!/usr/bin/env python3

import requests

api_url = "http://api.brain-map.org/api/v2/data"

def fetch_specimens():
    ### Get a list of specimen_ids from Allen API.
    specimens_uri = "http://api.brain-map.org/api/v2/data/query.json?criteria=model::ApiCellTypesSpecimenDetail,rma::criteria,[nr__reconstruction_type$nenull]"
    r = requests.get(specimens_uri)
    assert(r.status_code == 200)
    return [x['specimen__id'] for x in r.json()["msg"]]


def fetch_reconstructions(specimen_id):
    ### Get a list of reconstruction files for a given specimen.
    uri = f'{api_url}/query.json?criteria=model::NeuronReconstruction,rma::criteria,[specimen_id$eq{specimen_id}],rma::include,well_known_files'
    r = requests.get(uri)
    assert(r.status_code == 200)

    return(r.json()["msg"])

def handle_reconstruction(r):
    ### Get the URL of an .swc file and pass it to reuron.io swc converter.
    for f in r["well_known_files"]:
        if f["well_known_file_type_id"] == 303941301:
            link_suffix = f["download_link"]
            swc_url = f'http:/api.brain-map.org/{link_suffix}'

            print(swc_url)
            r = requests.get("https://reuron.io/convert-swc", data = swc_url)
            print(r.text)


def well_known_file_to_ffg(well_known_file_url):
    uri = "https://reuron.io/convert_swc"
    r.requests.post(uri, data=well_known_file_url)
    r.text()

x = fetch_specimens()
r1 = fetch_reconstructions(x[0])
handle_reconstruction(r1[0])
