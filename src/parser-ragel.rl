#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stdbool.h>

#include "parsers.h"
#include "parser-ragel.h"
#include "parsers-utils.h"
#include "utils.h"

%%{
	machine statsd;
	write data;
}%%

/**
 * Ragel parser entry point
 * Parsers given buffer and populates datagram with parsed data if they are valid
 * @arg str - Buffer to be parsed
 * @arg datagram - Placeholder for parsed data
 * @return 1 on success, 0 on fail 
 */
int
ragel_parser_parse(char* str, struct statsd_datagram** datagram) {
	*datagram = (struct statsd_datagram*) malloc(sizeof(struct statsd_datagram));
	*(*datagram) = (struct statsd_datagram) {0};
	ALLOC_CHECK("Not enough memory to save datagram");
	size_t length = strlen(str);
	char *p = str, *pe = (str + length + 1);
	char *eof = pe;
	int cs;
	size_t current_index = 0;
	size_t current_segment_start_index = 0;
	size_t instance_identifier_offset = strlen("instance=");
	struct tag_collection* tags;
	char* tag_key = NULL;
	char* tag_value = NULL;
	int tag_key_allocated = 0;
	int tag_value_allocated = 0;
	int any_tags = 0;

	%%{

		action error_handler {
			goto error_clean_up;
		}	

		action not_final_state_finish {
			goto error_clean_up;
		}	

		action increment_character_counter {
			current_index++;
		}

		action name_parsed {
			size_t current_segment_length = current_index - current_segment_start_index;
			(*datagram)->metric = (char*) malloc(current_segment_length + 1);
			ALLOC_CHECK("Not enough memory to save metric name");
			memcpy(
				(*datagram)->metric,
				&str[current_segment_start_index],
				current_segment_length
			);
			if (!sanitize_string((*datagram)->metric, current_segment_length)) {
				goto error_clean_up;
			}
			(*datagram)->metric[current_segment_length] = '\0';
			current_segment_start_index = current_index + 1; 
		}

		action instance_parsed {
			size_t current_segment_length = current_index - current_segment_start_index;
			(*datagram)->instance = (char*) malloc(current_segment_length + 1);
			ALLOC_CHECK("Not enough memory to save instance name");
			memcpy(
				(*datagram)->instance,
				&str[current_segment_start_index + instance_identifier_offset],
				current_segment_length - instance_identifier_offset
			);
			if (!sanitize_string(
				(*datagram)->instance,
				current_segment_length - (instance_identifier_offset + 1))) {
				goto error_clean_up;
			}
			(*datagram)->instance[current_segment_length] = '\0';
			current_segment_start_index = current_index + 1; 
		}		

		action tag_parsed {
			size_t key_len = strlen(tag_key);
			size_t value_len = strlen(tag_value);
			struct tag* t = (struct tag*) malloc(sizeof(struct tag));
			ALLOC_CHECK("Unable to allocate memory for tag.");
			t->key = (char*) malloc(key_len);
			ALLOC_CHECK("Unable to allocate memory for tag key.");
			memcpy(t->key, tag_key, key_len);
			t->value = (char*) malloc(value_len);
			ALLOC_CHECK("Unable to allocate memory for tag value.");
			memcpy(t->value, tag_value, value_len);
			if (any_tags == 0) {
				tags = (struct tag_collection*) malloc(sizeof(struct tag_collection));
				ALLOC_CHECK("Unable to allocate memory for tag collection.");
				*tags = (struct tag_collection) {0};
				any_tags = 1;
			}
			tags->values = (struct tag**) realloc(tags->values, sizeof(struct tag*) * (tags->length + 1));
			tags->values[tags->length] = t;
			tags->length++;
			free(tag_key);
			free(tag_value);
			tag_key = NULL;
			tag_value = NULL;
			tag_key_allocated = 0;
			tag_value_allocated = 0;
		}

		action value_parsed {
			size_t current_segment_length = current_index - current_segment_start_index;
			(*datagram)->value = (char*) malloc(current_segment_length + 1);
			ALLOC_CHECK("Not enough memory to save metric value");
			memcpy(
				(*datagram)->value,
				&str[current_segment_start_index],
				current_segment_length
			);
			(*datagram)->value[current_segment_length] = '\0';
			current_segment_start_index = current_index + 1;
		}

		action type_parsed {
			size_t current_segment_length = current_index - current_segment_start_index;
			(*datagram)->type = (char*) malloc(current_segment_length + 1);
			ALLOC_CHECK("Not enough memory to save metric type");
			memcpy(
				(*datagram)->type,
				&str[current_segment_start_index],
				current_segment_length
			);
			(*datagram)->type[current_segment_length] = '\0';
			current_segment_start_index = current_index + 1;
		}

		action sampling_parsed {
			size_t current_segment_length = current_index - current_segment_start_index;
			(*datagram)->sampling = (char*) malloc(current_segment_length + 1);
			ALLOC_CHECK("Not enough memory to save metric sampling");
			memcpy(
				(*datagram)->sampling,
				&str[current_segment_start_index],
				current_segment_length
			);
			(*datagram)->sampling[current_segment_length] = '\0';
			current_segment_start_index = current_index + 1;
		}

		action tag_key_parsed {
			size_t current_segment_length = current_index - current_segment_start_index;
			tag_key = (char *) realloc(tag_key, current_segment_length + 1);
			ALLOC_CHECK("Not enough memory for tag key buffer.");
			tag_key_allocated = 1;
			memcpy(
				tag_key,
				&str[current_segment_start_index], 
				current_segment_length
			);
			if (!sanitize_string(tag_key, current_segment_length)) {
				goto error_clean_up;
			}
			tag_key[current_segment_length] = '\0';
			current_segment_start_index = current_index + 1;
		}

		action tag_value_parsed {
			size_t current_segment_length = current_index - current_segment_start_index;
			tag_value = (char *) realloc(tag_value, current_segment_length + 1);
			ALLOC_CHECK("Not enough memory for tag key buffer.");
			tag_value_allocated = 1;
			memcpy(
				tag_value,
				&str[current_segment_start_index], 
				current_segment_length
			);
			if (!sanitize_string(tag_value, current_segment_length)) {
				goto error_clean_up;
			}
			tag_value[current_segment_length] = '\0';
			current_segment_start_index = current_index + 1;
		}

		str_value = [a-zA-Z0-9_\-/ .]{1,};
		name = str_value[:,]{1};
		value = ('+'|'-')?[0-9]{1,100}([.][0-9]{1,100})?('|');
		type = ('c'|'g'|'ms')('@'|'\0'|'\n\0');
		instance = 'instance='str_value(':'|',');
		tags = (((str_value -- 'instance')'=')@tag_key_parsed(str_value(':'|',')@tag_value_parsed))+;
		sampling = ([0-9]{1,100}([.][0-9]{1,100})?)('\0'|'\n\0');

		main := 
			  ((name @name_parsed . ((instance @instance_parsed)? . (tags @ tag_parsed)?)? . value @value_parsed . type @type_parsed . (sampling @sampling_parsed)?))
			  $~increment_character_counter @!error_handler @/not_final_state_finish;
		# */
		# Initialize and execute.
		write init;
		write exec;

	}%%
	if (any_tags) {
		char* json = tag_collection_to_json(tags);
		if (json != NULL) {
			(*datagram)->tags = malloc(strlen(json) + 1);
			(*datagram)->tags = json;
		}
		free(tags);
		if (tag_key_allocated) free(tag_key);
		if (tag_value_allocated) free(tag_value);
	}
	if (str[length - 1] == '\n')
        str[length - 1] = 0;
	verbose_log("Parsed: %s", str);
	return 1;

	error_clean_up:
	if (tag_key_allocated) free(tag_key);
	if (tag_value_allocated) free(tag_value);
	if (str[length - 1] == '\n')
        str[length - 1] = 0;
	free_datagram(*datagram);
	verbose_log("Throwing away datagram. REASON: unable to parse: %s", str);
	return 0;
};


/**
 * --------------------------------------
 * |                                    |
 * |     UNIT TEST FOR THIS FILE        |
 * |                                    |
 * --------------------------------------
 */
#if _TEST_TARGET == 2

int
main() {
    INIT_TEST("Running tests for ragel parser:", ragel_parser_parse);
    SUITE_HEADER("Unparsable values")
    CHECK_ERROR("", NULL, NULL, NULL, NULL, NULL, NULL);
    CHECK_ERROR("wow", NULL, NULL, NULL, NULL, NULL, NULL);
    CHECK_ERROR("wow:2", NULL, NULL, NULL, NULL, NULL, NULL);
    CHECK_ERROR("wow|g", NULL, NULL, NULL, NULL, NULL, NULL);
    CHECK_ERROR("2|g", NULL, NULL, NULL, NULL, NULL, NULL);
    SUITE_HEADER("Basic values")
    CHECK_ERROR("example:1|c", "example", NULL, NULL, "1", "c", NULL);
    CHECK_ERROR("example:1|g", "example", NULL, NULL, "1", "g", NULL);
    CHECK_ERROR("example:1|ms", "example", NULL, NULL, "1", "ms", NULL);
    CHECK_ERROR("1:1|c", "1", NULL, NULL, "1", "c", NULL);
    SUITE_HEADER("Sanitizable metric name");
    CHECK_ERROR("e x-2 ple:20|c", "e_x_2_ple", NULL, NULL, "20", "c", NULL);
    SUITE_HEADER("Non integer values")
    CHECK_ERROR("example:1.2|c", "example", NULL, NULL, "1.2", "c", NULL);
    CHECK_ERROR("example:1.000000004|c", "example", NULL, NULL, "1.000000004", "c", NULL);
    CHECK_ERROR("example:1.00000000000000000000000000000004|c", "example", NULL, NULL, "1.00000000000000000000000000000004", "c", NULL);
    SUITE_HEADER("Instance descriptors")
    CHECK_ERROR("example,instance=20:20|c", "example", NULL, "20", "20", "c", NULL);
    SUITE_HEADER("Tag descriptors")
    CHECK_ERROR("example,tagY=20,tagX=10:10|c", "example", "{\"tagX\":\"10\",\"tagY\":\"20\"}", NULL, "10", "c", NULL);
    SUITE_HEADER("Malformed tags")
    CHECK_ERROR("example,tags=dwq=qwddqwd=qwd:10|c", NULL, NULL, NULL, NULL, NULL, NULL);
    SUITE_HEADER("Too long tag descriptor (gets thrown away)")
    CHECK_ERROR("example,tags=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:10|c", "example", NULL, NULL, "10", "c", NULL);
    SUITE_HEADER("Sampling")
    CHECK_ERROR("example:20|c@0.5", "example", NULL, NULL, "20", "c", "0.5");
    CHECK_ERROR("example:20|c@15", "example", NULL, NULL, "20", "c", "15");
    END_TEST();
}

#endif