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

    def parse_reconstruction(j):
        print(j)
        ret = {}
        print(j.keys())
        print(j.get("id"))
        ret.well_known_files = []
        for f in j["well_known_files"]:
            fobj = {}
            fobj.id = f["id"]
            fobj.path = f["path"]
            fobj.download_link = f["download_link"]
            fobj.well_known_file_type_id = f["well_known_file_type_id"]
            ret.well_known_files.push(fobj)
        return(ret)

    return([parse_reconstruction(x) for x in r.json()["msg"]])

def handle_reconstruction(r):
    for f in r.well_known_files:
        if f.well_known_file_type_id == 303941301:
            print(f.download_link)
            # print(well_known_file_to_ffg(f.download_link))

def well_known_file_to_ffg(well_known_file_url):
    uri = "https://reuron.io/convert_swc"
    r.requests.post(uri, data=well_known_file_url)
    r.text()

x = fetch_specimens()
r1 = fetch_reconstructions(x[0])
handle_reconstruction(r1)
