
#include <chan/chan.h>
#include <string.h>

#include "config-reader.h"
#include "network-listener.h"
#include "parsers.h"
#include "parser-basic.h"
#include "parser-ragel.h"
#include "utils.h"

/**
 * Thread entrypoint - listens to incoming payload on a unprocessed channel and sends over successfully parsed data over to Aggregator thread via processed channel
 * @arg args - parser_args
 */
void*
parser_exec(void* args) {
    chan_t* unprocessed_channel = ((struct parser_args*)args)->unprocessed_datagrams;
    chan_t* parsed_channel = ((struct parser_args*)args)->parsed_datagrams;
    struct agent_config* config = ((struct parser_args*)args)->config;
    datagram_parse_callback parse_datagram;
    if ((int)config->parser_type == (int)PARSER_TYPE_BASIC) {
        parse_datagram = &basic_parser_parse;
    } else {
        parse_datagram = &ragel_parser_parse;
    }
    struct unprocessed_statsd_datagram* datagram =
        (struct unprocessed_statsd_datagram*) malloc(sizeof(struct unprocessed_statsd_datagram));
    ALLOC_CHECK("Unable to allocate space for unprocessed statsd datagram.");
    while(1) {
        *datagram = (struct unprocessed_statsd_datagram) { 0 };
        chan_recv(unprocessed_channel, (void *)&datagram);
        struct statsd_datagram* parsed;
        char delim[] = "\n";
        char* tok = strtok(datagram->value, delim);
        while (tok != NULL) {
            int success = parse_datagram(tok, &parsed);
            if (success) {            
                chan_send(parsed_channel, parsed);
            }
            tok = strtok(NULL, delim);
        }
    }
}

/**
 * Creates arguments for parser thread
 * @arg config - Application config
 * @arg unprocessed_channel - Network listener -> Parser
 * @arg parsed_channel - Parser -> Aggregator
 * @return parser_args
 */
struct parser_args*
create_parser_args(struct agent_config* config, chan_t* unprocessed_channel, chan_t* parsed_channel) {
    struct parser_args* parser_args = (struct parser_args*) malloc(sizeof(struct parser_args));
    ALLOC_CHECK("Unable to assign memory for parser arguments.");
    parser_args->config = config;
    parser_args->unprocessed_datagrams = unprocessed_channel;
    parser_args->parsed_datagrams = parsed_channel;
    return parser_args;
}

/**
 * Prints out parsed datagram structure in human readable form.
 */
void
print_out_datagram(struct statsd_datagram* datagram) {
    printf("DATAGRAM: \n");
    printf("metric: %s \n", datagram->metric);
    printf("instance: %s \n", datagram->instance);
    printf("tags: %s \n", datagram->tags);
    printf("value: %s \n", datagram->value);
    printf("type: %s \n", datagram->type);
    printf("sampling: %s \n", datagram->sampling);
    printf("------------------------------ \n");
}

/**
 * Frees datagram
 */
void
free_datagram(struct statsd_datagram* datagram) {
    if (datagram->metric != NULL) {
        free(datagram->metric);
    }
    if (datagram->instance != NULL) {
        free(datagram->instance);
    }
    if (datagram->tags != NULL) {
        free(datagram->tags);
    }
    if (datagram->type != NULL) {
        free(datagram->type);
    }
    if (datagram->sampling != NULL) {
        free(datagram->sampling);
    }
    if (datagram != NULL) {
        free(datagram);
    }
}